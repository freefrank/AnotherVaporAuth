import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/device_session.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';
import 'community_session.dart';

/// Steam device / session management (`IAuthenticationService`).
///
/// Field numbers follow SteamDatabase/Protobufs
/// `steam/steammessages_auth.steamclient.proto` — verbatim-checked; see
/// `docs/specs/device-sessions.md`. All calls authenticate with the account's
/// access token.
///
/// [enumerate] lists the account's logged-in devices; [revoke] signs a device
/// out remotely. The revoke `signature` scheme was reverse-engineered from the
/// official Steam app (see `docs/specs/2026-07-18-device-sessions-design.md`
/// §Revoke and memory `steam-revoke-signature`) — HMAC-SHA256 over the
/// token_id's *decimal ASCII*, keyed with the shared secret; NOT the
/// little-endian layout the QR-approve signature uses.
class SessionsClient {
  final SteamApiClient api;
  SessionsClient(this.api);

  /// Lists every refresh token (logged-in device / browser session) for the
  /// account, newest activity first, and flags which one is *this* device.
  Future<DeviceSessionList> enumerate(SteamGuardAccount account) async {
    final token = requireAccessToken(account);
    // include_revoked defaults to false — an empty body is the "active only"
    // request. EnumerateTokens is NOT a bConstMethod (unlike the neighbouring
    // GetAuthSessionsForAccount), so it MUST be POST: sending it as GET is the
    // wrong call shape. Leave useGet at its false default.
    final reader = await api.callProtobuf(
      'IAuthenticationService',
      'EnumerateTokens',
      request: ProtoWriter(),
      accessToken: token,
    );
    final devices = <DeviceSession>[];
    var requestingTokenId = '';
    for (final f in reader.parseAll()) {
      switch (f.number) {
        case 1: // repeated RefreshTokenDescription
          if (f.bytes != null) devices.add(_device(f.bytes!));
        case 2: // requesting_token (fixed64) — the calling device's token_id
          requestingTokenId = _uFixed64(f.bytes);
      }
    }
    // Most-recently-updated first; a stable, user-meaningful order.
    devices.sort((a, b) => b.timeUpdated.compareTo(a.timeUpdated));
    dlog('sessions enumerate: ${devices.length} device(s), '
        'current=${requestingTokenId.isEmpty ? '?' : requestingTokenId}');
    return DeviceSessionList(
        devices: devices, requestingTokenId: requestingTokenId);
  }

  /// Remotely signs [device] out of the account (`RevokeRefreshToken`).
  ///
  /// [permanent] true → `k_EAuthTokenRevokePermanent` (1, deauthorize); false →
  /// `k_EAuthTokenRevokeLogout` (0). Steam answers a success with an empty body
  /// (eresult OK); [callProtobuf] throws on any non-OK eresult, so returning
  /// normally means it took — we never read a `success` bool.
  ///
  /// The caller must not pass the current device (`DeviceSessionList.isCurrent`)
  /// — that would sign the app itself out; the UI hides revoke for it.
  Future<void> revoke(SteamGuardAccount account, DeviceSession device,
      {bool permanent = true}) async {
    final token = requireAccessToken(account);
    if (device.tokenId.isEmpty) {
      throw ArgumentError('device has no token_id');
    }
    final signature = revokeSignature(account.sharedSecret, device.tokenId);
    final req = ProtoWriter()
      ..writeFixed64(1, _decimalToSignedInt64(device.tokenId)) // token_id
      ..writeFixed64(2, account.steamId) // steamid
      ..writeVarint(3, permanent ? 1 : 0) // revoke_action
      ..writeBytes(4, signature); // signature (raw 32 HMAC bytes)
    // RevokeRefreshToken is NOT a bConstMethod → POST (default useGet:false).
    await api.callProtobuf(
      'IAuthenticationService',
      'RevokeRefreshToken',
      request: req,
      accessToken: token,
    );
    dlog('sessions revoke: token=${device.tokenId} '
        'action=${permanent ? 'permanent' : 'logout'} OK');
  }

  /// The `signature` for [RevokeRefreshToken]: HMAC-SHA256 keyed with the
  /// base64-decoded [sharedSecretB64], over the ASCII of [tokenIdDecimal] (the
  /// token_id rendered in base 10). Reverse-engineered from Steam Android
  /// 3.10.9 — deliberately NOT the little-endian integer layout the QR-approve
  /// signature uses. Returns the raw 32 MAC bytes.
  static Uint8List revokeSignature(String? sharedSecretB64, String tokenIdDecimal) {
    final key = base64.decode((sharedSecretB64 ?? '').trim());
    final msg = ascii.encode(tokenIdDecimal);
    return Uint8List.fromList(Hmac(sha256, key).convert(msg).bytes);
  }

  /// token_id is stored as an unsigned decimal string (see [_uFixed64]); to
  /// write it as a wire-1 fixed64 we need the Dart int with the same 64 bits.
  /// BigInt.toInt() would clamp values above 2^63, so reinterpret the low 64
  /// bits as signed first — [ProtoWriter.writeFixed64] re-widens negatives back
  /// to the original unsigned bytes.
  static int _decimalToSignedInt64(String decimal) =>
      BigInt.parse(decimal).toSigned(64).toInt();

  DeviceSession _device(Uint8List bytes) {
    var tokenId = '';
    var description = '';
    var timeUpdated = 0;
    var platformType = 0;
    var loggedIn = false;
    DeviceUsage? lastSeen;
    for (final f in ProtoReader(bytes).parseAll()) {
      switch (f.number) {
        case 1: // token_id (fixed64)
          tokenId = _uFixed64(f.bytes);
        case 2: // token_description
          description = f.asString;
        case 3: // time_updated
          timeUpdated = f.asInt;
        case 4: // platform_type (enum)
          platformType = f.asInt;
        case 5: // logged_in
          loggedIn = f.asBool;
        case 10: // last_seen (TokenUsageEvent)
          if (f.bytes != null) lastSeen = _usage(f.bytes!);
      }
    }
    return DeviceSession(
      tokenId: tokenId,
      description: description,
      timeUpdated: timeUpdated,
      platformType: platformType,
      loggedIn: loggedIn,
      lastSeen: lastSeen,
    );
  }

  DeviceUsage _usage(Uint8List bytes) {
    var time = 0;
    var country = '';
    var state = '';
    var city = '';
    for (final f in ProtoReader(bytes).parseAll()) {
      switch (f.number) {
        case 1: // time
          time = f.asInt;
        case 4: // country
          country = f.asString;
        case 5: // state
          state = f.asString;
        case 6: // city
          city = f.asString;
      }
    }
    return DeviceUsage(time: time, country: country, state: state, city: city);
  }

  /// Decodes a wire-type-1 (fixed64) field's 8 little-endian bytes as an
  /// *unsigned* 64-bit value rendered as a decimal string. token_id is a
  /// handle, not a number, and its top bit is often set — ProtoField.asFixed64
  /// would sign-flip those to a negative int that no longer round-trips back to
  /// Steam. Returns '' when the field is absent/short.
  static String _uFixed64(Uint8List? b) {
    if (b == null || b.length < 8) return '';
    var big = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      big = (big << 8) | BigInt.from(b[i]);
    }
    return big.toString();
  }
}
