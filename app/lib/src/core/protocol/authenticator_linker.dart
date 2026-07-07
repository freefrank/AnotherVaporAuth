import 'dart:convert';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../../services/steam_time.dart';
import '../models/session_data.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';
import '../steam_totp.dart';

enum LinkResult {
  mustProvidePhoneNumber,
  mustConfirmEmail,
  awaitingFinalization,
  generalFailure,
  authenticatorPresent,
  accountLocked, // EResult 73 — account is locked/restricted by Steam
  rateLimited, // EResult 84 — too many attempts, try later
}

enum FinalizeResult {
  badSmsCode,
  unableToGenerateCorrectCodes,
  success,
  generalFailure,
}

/// Links a new Steam Guard mobile authenticator to an account (requires a
/// logged-in [SessionData]). Port of the modern `ITwoFactorService` /
/// `IPhoneService` flow used by geel9/SteamAuth.
///
/// Field numbers/types follow the SteamKit/SteamDatabase protobufs:
/// `steamid` is **fixed64** in both AddAuthenticator and FinalizeAddAuthenticator.
class AuthenticatorLinker {
  final SteamApiClient api;
  final SessionData session;

  String? phoneNumber; // E.164, e.g. +1234567890
  String phoneCountryCode = '';
  SteamGuardAccount? linkedAccount;

  /// How Steam will deliver the activation code (from AddAuthenticator's
  /// `confirm_type`): 3 = email (no phone), otherwise SMS to the account phone.
  int _confirmType = 0;
  bool get activatesByEmail => _confirmType == 3;

  /// Seams for [finalize]'s window timing — overridable in tests so the retry
  /// logic can run without real 30-second waits.
  final int Function() now;
  final Future<void> Function(Duration) sleep;

  AuthenticatorLinker(
    this.api,
    this.session, {
    int Function()? now,
    Future<void> Function(Duration)? sleep,
  })  : now = now ?? (() => SteamTime.currentSteamTime),
        sleep = sleep ?? Future.delayed;

  String get _accessToken => session.accessToken ?? '';

  /// Drives AddAuthenticator. The response `status` decides the next step,
  /// matching Steam's flow:
  ///   1  -> secrets returned (awaitingFinalization)
  ///   2  -> the account needs a phone first
  ///   29 -> an authenticator is already present
  Future<LinkResult> addAuthenticator() async {
    final deviceId =
        linkedAccount?.deviceId ?? SteamTotp.generateDeviceId(session.steamId);

    final req = ProtoWriter()
      ..writeFixed64(1, session.steamId) // steamid (fixed64!)
      ..writeUint64(2, SteamTime.currentSteamTime) // authenticator_time
      ..writeVarint(4, 1) // authenticator_type
      ..writeString(5, deviceId) // device_identifier
      ..writeString(6, '1') // sms_phone_id
      ..writeVarint(8, 2); // version

    final Map<int, ProtoField> parsed;
    try {
      parsed = (await api.callProtobuf(
        'ITwoFactorService',
        'AddAuthenticator',
        request: req,
        accessToken: _accessToken,
      ))
          .parse();
    } on SteamApiException catch (e) {
      dlog('AddAuthenticator failed: eresult ${e.eresult}');
      switch (e.eresult) {
        case 29: // DuplicateRequest — an authenticator is already present
          return LinkResult.authenticatorPresent;
        case 73: // AccountLockedDown
          return LinkResult.accountLocked;
        case 84: // RateLimitExceeded
          return LinkResult.rateLimited;
        default:
          return LinkResult.generalFailure;
      }
    }
    final fields = parsed;

    final status = fields[10]?.asInt ?? 0;
    final sharedSecret = fields[1]?.bytes;
    // confirm_type (field 12) tells us how Steam will deliver the activation
    // code: SMS for phone accounts, email otherwise. phone_number_hint (11) is
    // set when a phone is involved.
    _confirmType = fields[12]?.asInt ?? 0;
    final phoneHint = fields[11]?.asString ?? '';
    dlog('AddAuthenticator: status=$status sharedSecret=${sharedSecret?.length ?? 0}B '
        'confirmType=$_confirmType phoneHint="$phoneHint"');

    if (status == 29) return LinkResult.authenticatorPresent;

    if (status == 2 || sharedSecret == null || sharedSecret.isEmpty) {
      // Account needs a phone number first.
      if (phoneNumber == null || phoneNumber!.isEmpty) {
        return LinkResult.mustProvidePhoneNumber;
      }
      final added = await _addPhoneNumber(phoneNumber!, phoneCountryCode);
      // Steam emails the user to confirm the new phone; they must click it,
      // then we retry AddAuthenticator.
      return added ? LinkResult.mustConfirmEmail : LinkResult.generalFailure;
    }

    linkedAccount = SteamGuardAccount(
      sharedSecret: base64.encode(sharedSecret),
      serialNumber: '${fields[2]?.asFixed64 ?? 0}',
      revocationCode: fields[3]?.asString,
      uri: fields[4]?.asString,
      serverTime: fields[5]?.asInt ?? 0,
      accountName: fields[6]?.asString,
      tokenGid: fields[7]?.asString,
      identitySecret:
          fields[8]?.bytes != null ? base64.encode(fields[8]!.bytes!) : null,
      secret1:
          fields[9]?.bytes != null ? base64.encode(fields[9]!.bytes!) : null,
      status: status,
      deviceId: deviceId,
      fullyEnrolled: false,
      session: session,
    );
    return LinkResult.awaitingFinalization;
  }

  /// Finalizes the link with the [activationCode] Steam delivered — via SMS for
  /// phone accounts, or via email when the account has no phone. Steam wants a
  /// run of correct TOTP codes; it asks for more via `want_more` until aligned.
  /// Seconds a caller must wait after submitting a code at [lastSubmitTime]
  /// before a *new* TOTP window (hence a different code) is available at
  /// [now]. Returns 0 once [now] is already in a later 30-second window.
  /// Steam Guard codes are stable for the whole window, so retrying inside
  /// the same one just resubmits the identical code — the old tight loop
  /// could burn every retry on one code and trip rate limits.
  static int windowWaitSeconds(int lastSubmitTime, int now) {
    if (now ~/ 30 > lastSubmitTime ~/ 30) return 0;
    // Time left in the window that lastSubmitTime belongs to, measured from
    // now, plus a 1s buffer to be safely past the boundary.
    final windowEnd = (lastSubmitTime ~/ 30 + 1) * 30;
    final wait = windowEnd - now + 1;
    return wait > 0 ? wait : 1;
  }

  Future<FinalizeResult> finalize(String activationCode) async {
    final account = linkedAccount;
    if (account == null) return FinalizeResult.generalFailure;

    // Steam asks for a short run of consecutive codes; each must come from a
    // fresh window, so cap by distinct windows rather than a tight loop.
    var tries = 0;
    var lastSubmit = -1;
    while (tries < 5) {
      if (lastSubmit >= 0) {
        final wait = windowWaitSeconds(lastSubmit, now());
        if (wait > 0) await sleep(Duration(seconds: wait));
      }
      final time = now();
      final code = account.generateCode(time);
      lastSubmit = time;
      final req = ProtoWriter()
        ..writeFixed64(1, session.steamId) // steamid (fixed64!)
        ..writeString(2, code) // authenticator_code
        ..writeUint64(3, time) // authenticator_time
        ..writeString(4, activationCode) // activation_code (SMS or email)
        ..writeBool(6, !activatesByEmail); // validate_sms_code

      final fields = (await api.callProtobuf(
        'ITwoFactorService',
        'FinalizeAddAuthenticator',
        request: req,
        accessToken: _accessToken,
      ))
          .parse();

      final success = fields[1]?.asBool ?? false;
      final wantMore = fields[2]?.asBool ?? false;
      final status = fields[4]?.asInt ?? 0;
      dlog('Finalize: success=$success wantMore=$wantMore status=$status try=$tries');

      if (status == 89) return FinalizeResult.badSmsCode;
      if (success) {
        account.fullyEnrolled = true;
        return FinalizeResult.success;
      }
      if (wantMore || status == 88) {
        tries++;
        continue;
      }
      return FinalizeResult.generalFailure;
    }
    return FinalizeResult.unableToGenerateCorrectCodes;
  }

  /// Adds a phone number to the account (CPhoneService/SetAccountPhoneNumber).
  /// Steam then sends a confirmation email; the caller surfaces
  /// [LinkResult.mustConfirmEmail] so the user can click it before retrying.
  Future<bool> _addPhoneNumber(String number, String countryCode) async {
    try {
      final req = ProtoWriter()..writeString(1, number); // phone_number
      if (countryCode.isNotEmpty) req.writeString(2, countryCode);
      await api.callProtobuf(
        'IPhoneService',
        'SetAccountPhoneNumber',
        request: req,
        accessToken: _accessToken,
      );
      return true;
    } catch (e) {
      dlog('SetAccountPhoneNumber failed: $e');
      return false;
    }
  }

  /// Whether the account is still waiting for the user to click the phone
  /// confirmation email. Poll this before retrying [addAuthenticator].
  Future<bool> isAwaitingEmailConfirmation() async {
    try {
      final fields = (await api.callProtobuf(
        'IPhoneService',
        'IsAccountWaitingForEmailConfirmation',
        request: ProtoWriter(),
        accessToken: _accessToken,
      ))
          .parse();
      return fields[1]?.asBool ?? false; // awaiting_email_confirmation
    } catch (_) {
      return false;
    }
  }

}
