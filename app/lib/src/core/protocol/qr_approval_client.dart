import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';

/// Parsed components of a Steam login QR challenge URL,
/// e.g. `https://s.team/q/<version>/<client_id>`.
class QrChallenge {
  final int version;
  final int clientId;
  const QrChallenge(this.version, this.clientId);

  /// Parses the challenge URL embedded in a login QR code.
  static QrChallenge? tryParse(String raw) {
    final input = raw.trim();
    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    // Path looks like /q/<version>/<client_id> (host s.team or steamcommunity).
    final segs = uri.pathSegments;
    final qIdx = segs.indexOf('q');
    if (qIdx >= 0 && segs.length >= qIdx + 3) {
      final version = int.tryParse(segs[qIdx + 1]);
      final clientId = int.tryParse(segs[qIdx + 2]);
      if (version != null && clientId != null) {
        return QrChallenge(version, clientId);
      }
    }
    return null;
  }
}

/// Details of a pending login session (GetAuthSessionInfo) shown to the user
/// before they approve or deny it.
class AuthSessionInfo {
  final int clientId;
  final int version;
  final String ip;
  final String city;
  final String country;
  final String deviceName;
  const AuthSessionInfo({
    required this.clientId,
    required this.version,
    required this.ip,
    required this.city,
    required this.country,
    required this.deviceName,
  });

  String get location => [city, country].where((s) => s.isNotEmpty).join(', ');
}

/// Direction B: this app acts as the approver for a login started elsewhere —
/// either by scanning the login QR, or by polling the account's own pending
/// login sessions (GetAuthSessionsForAccount) so they can be approved like the
/// official app's pop-up, without a push.
class QrApprovalClient {
  final SteamApiClient api;
  QrApprovalClient(this.api);

  /// Lists client ids of pending login sessions awaiting approval for [account].
  Future<List<int>> pendingLoginClientIds(SteamGuardAccount account) async {
    final fields = (await api.callProtobuf(
      'IAuthenticationService',
      'GetAuthSessionsForAccount',
      request: ProtoWriter(),
      accessToken: account.session.accessToken ?? '',
    ))
        .parseAll();
    final ids = <int>[];
    for (final f in fields) {
      if (f.number != 1) continue;
      if (f.varint != null) {
        ids.add(f.varint!); // unpacked repeated uint64
      } else if (f.bytes != null) {
        // packed repeated varint
        final b = f.bytes!;
        var i = 0;
        while (i < b.length) {
          var shift = 0;
          var val = BigInt.zero;
          while (i < b.length) {
            final byte = b[i++];
            val |= BigInt.from(byte & 0x7f) << shift;
            if (byte & 0x80 == 0) break;
            shift += 7;
          }
          ids.add(val.toSigned(64).toInt());
        }
      }
    }
    return ids;
  }

  /// Fetches details (IP / location / device / version) for a pending login.
  Future<AuthSessionInfo?> sessionInfo(
      SteamGuardAccount account, int clientId) async {
    final req = ProtoWriter()..writeUint64(1, clientId);
    final f = (await api.callProtobuf(
      'IAuthenticationService',
      'GetAuthSessionInfo',
      request: req,
      accessToken: account.session.accessToken ?? '',
    ))
        .parse();
    return AuthSessionInfo(
      clientId: clientId,
      version: f[8]?.asInt ?? 0,
      ip: f[1]?.asString ?? '',
      city: f[3]?.asString ?? '',
      country: f[5]?.asString ?? '',
      deviceName: f[7]?.asString ?? '',
    );
  }

  /// Approves (or rejects) a scanned login challenge using [account]'s session.
  Future<bool> respond(
    SteamGuardAccount account,
    QrChallenge challenge, {
    required bool approve,
  }) =>
      respondToSession(account,
          version: challenge.version,
          clientId: challenge.clientId,
          approve: approve);

  /// Approves/denies a specific auth session (by client id + version). Signs the
  /// (version, client_id, steamid) tuple with the account's shared secret
  /// (HMAC-SHA256) and calls UpdateAuthSessionWithMobileConfirmation.
  Future<bool> respondToSession(
    SteamGuardAccount account, {
    required int version,
    required int clientId,
    required bool approve,
  }) async {
    final accessToken = account.session.accessToken ?? '';
    final signature = _signature(account,
        version: version, clientId: clientId, steamId: account.steamId);

    final req = ProtoWriter()
      ..writeVarint(1, version) // version (int32)
      ..writeUint64(2, clientId) // client_id (uint64 varint)
      ..writeFixed64(3, account.steamId) // steamid (fixed64!)
      ..writeBytes(4, signature) // signature
      ..writeBool(5, approve) // confirm
      ..writeVarint(6, 1); // persistence = Persistent

    final fields = (await api.callProtobuf(
      'IAuthenticationService',
      'UpdateAuthSessionWithMobileConfirmation',
      request: req,
      accessToken: accessToken,
    ))
        .parse();
    // Empty success response (eresult OK) means accepted.
    return fields.isEmpty || (fields[1]?.asBool ?? true);
  }

  /// HMAC-SHA256 over the little-endian (version|client_id|steamid) tuple,
  /// keyed with the account's base64 shared secret. This is the signature Steam
  /// expects for UpdateAuthSessionWithMobileConfirmation.
  Uint8List _signature(
    SteamGuardAccount account, {
    required int version,
    required int clientId,
    required int steamId,
  }) {
    final key = base64.decode((account.sharedSecret ?? '').trim());
    final buf = BytesBuilder();
    buf.add(_le16(version));
    buf.add(_le64(clientId));
    buf.add(_le64(steamId));
    return Uint8List.fromList(Hmac(sha256, key).convert(buf.toBytes()).bytes);
  }

  List<int> _le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  List<int> _le64(int v) {
    final out = List<int>.filled(8, 0);
    var x = v;
    for (var i = 0; i < 8; i++) {
      out[i] = x & 0xFF;
      x >>= 8;
    }
    return out;
  }
}
