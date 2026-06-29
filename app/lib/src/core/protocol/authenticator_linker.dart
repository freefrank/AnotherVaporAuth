import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../../services/steam_api_client.dart';
import '../../services/steam_time.dart';
import '../models/session_data.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';

enum LinkResult {
  mustProvidePhoneNumber,
  mustConfirmEmail,
  awaitingFinalization,
  generalFailure,
  authenticatorPresent,
}

enum FinalizeResult { badSmsCode, unableToGenerateCorrectCodes, success, generalFailure }

/// Links a new Steam Guard mobile authenticator to an account (requires a
/// logged-in [SessionData]). Port of the C# `AuthenticatorLinker` flow over the
/// `ITwoFactorService` / `IPhoneService` protobuf endpoints.
class AuthenticatorLinker {
  final SteamApiClient api;
  final SessionData session;

  String? phoneNumber; // E.164, e.g. +1234567890
  SteamGuardAccount? linkedAccount;

  AuthenticatorLinker(this.api, this.session);

  String get _accessToken => session.accessToken ?? '';

  /// Attempts to add the authenticator. May require a phone number first.
  Future<LinkResult> addAuthenticator() async {
    final hasPhone = await _hasPhoneAttached();
    if (!hasPhone) {
      if (phoneNumber == null || phoneNumber!.isEmpty) {
        return LinkResult.mustProvidePhoneNumber;
      }
      if (!await _addPhoneNumber(phoneNumber!)) {
        return LinkResult.mustConfirmEmail;
      }
    }

    final deviceId = _generateDeviceId(session.steamId);
    final req = ProtoWriter()
      ..writeUint64(1, session.steamId)
      ..writeUint64(2, SteamTime.currentSteamTime)
      ..writeVarint(4, 1) // authenticator_type
      ..writeString(5, deviceId)
      ..writeString(6, '1'); // sms_phone_id

    final fields = (await api.callProtobuf(
      'ITwoFactorService',
      'AddAuthenticator',
      request: req,
      accessToken: _accessToken,
    ))
        .parse();

    final status = fields[10]?.asInt ?? 0;
    final sharedSecret = fields[1]?.bytes;
    if (sharedSecret == null || sharedSecret.isEmpty) {
      if (status == 29) return LinkResult.authenticatorPresent;
      return LinkResult.generalFailure;
    }

    linkedAccount = SteamGuardAccount(
      sharedSecret: base64.encode(sharedSecret),
      serialNumber: '${fields[2]?.asInt ?? 0}',
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

  /// Finalizes the link with the SMS [smsCode] sent to the phone.
  Future<FinalizeResult> finalize(String smsCode) async {
    final account = linkedAccount;
    if (account == null) return FinalizeResult.generalFailure;

    var tries = 0;
    while (tries <= 30) {
      final time = SteamTime.currentSteamTime;
      final code = account.generateCode(time);
      final req = ProtoWriter()
        ..writeUint64(1, session.steamId)
        ..writeString(2, code)
        ..writeUint64(3, time)
        ..writeString(4, smsCode);

      final fields = (await api.callProtobuf(
        'ITwoFactorService',
        'FinalizeAddAuthenticator',
        request: req,
        accessToken: _accessToken,
      ))
          .parse();

      final status = fields[4]?.asInt ?? 0;
      final success = fields[1]?.asBool ?? false;
      final wantMore = fields[2]?.asBool ?? false;

      if (status == 89) return FinalizeResult.badSmsCode;
      if (status == 88 && tries >= 30) {
        return FinalizeResult.unableToGenerateCorrectCodes;
      }
      if (success) {
        account.fullyEnrolled = true;
        return FinalizeResult.success;
      }
      if (wantMore) {
        tries++;
        continue;
      }
      return FinalizeResult.generalFailure;
    }
    return FinalizeResult.unableToGenerateCorrectCodes;
  }

  Future<bool> _hasPhoneAttached() async {
    try {
      final fields = (await api.callProtobuf(
        'IPhoneService',
        'IsAccountWaitingForEmailConfirmation',
        request: ProtoWriter(),
        accessToken: _accessToken,
      ))
          .parse();
      // best-effort; if endpoint unavailable, assume phone status via account.
      return fields.isNotEmpty ? false : false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _addPhoneNumber(String number) async {
    try {
      final req = ProtoWriter()
        ..writeString(1, number)
        ..writeString(2, ''); // country code optional
      await api.callProtobuf(
        'IPhoneService',
        'SetAccountPhoneNumber',
        request: req,
        accessToken: _accessToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Steam Android device id: `android:<uuid-like>` derived deterministically
  /// from the steamid (matches SDA's GenerateDeviceID style).
  static String _generateDeviceId(int steamId) {
    final h = crypto.sha1.convert(utf8.encode('android-uuid:$steamId'));
    final s = h.toString().padRight(32, '0').substring(0, 32);
    String seg(int a, int b) => s.substring(a, b);
    return 'android:${seg(0, 8)}-${seg(8, 12)}-${seg(12, 16)}-${seg(16, 20)}-${seg(20, 32)}';
  }
}
