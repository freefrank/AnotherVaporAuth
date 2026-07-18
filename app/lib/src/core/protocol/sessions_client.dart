import 'dart:typed_data';

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
/// Read-only for now: [enumerate] lists the account's logged-in devices.
/// Revoking a specific device (`RevokeRefreshToken`) needs an HMAC `signature`
/// over `token_id` whose derivation Steam does not document and no public
/// reference implementation computes — deliberately not implemented until that
/// scheme is verified (see the spec's §Revoke). Never guess it.
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
