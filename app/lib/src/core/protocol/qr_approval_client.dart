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

/// Direction B: this app acts as the approver for a login started elsewhere.
/// Scans / pastes the login QR, then approves it via the account's session.
class QrApprovalClient {
  final SteamApiClient api;
  QrApprovalClient(this.api);

  /// Approves (or rejects) a scanned login challenge using [account]'s session.
  ///
  /// Signs the (version, client_id, steamid) tuple with the account's shared
  /// secret (HMAC-SHA1), then calls UpdateAuthSessionWithMobileConfirmation.
  ///
  /// Message fields follow the SteamKit protobufs (steamid is fixed64);
  /// the signature is HMAC-SHA256 of (version|client_id|steamid). Direction B is
  /// less common — worth a final live-capture check.
  Future<bool> respond(
    SteamGuardAccount account,
    QrChallenge challenge, {
    required bool approve,
  }) async {
    final accessToken = account.session.accessToken ?? '';
    final signature = _signature(
      account,
      version: challenge.version,
      clientId: challenge.clientId,
      steamId: account.steamId,
    );

    final req = ProtoWriter()
      ..writeVarint(1, challenge.version) // version (int32)
      ..writeUint64(2, challenge.clientId) // client_id (uint64 varint)
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
