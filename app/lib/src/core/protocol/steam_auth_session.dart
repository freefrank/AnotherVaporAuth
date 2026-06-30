import 'dart:convert';
import 'dart:typed_data';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../crypto/steam_rsa.dart';
import '../models/session_data.dart';
import '../proto/protobuf_wire.dart';

/// Steam guard types that may gate an auth session.
enum GuardType {
  none,
  emailCode, // 2
  deviceCode, // 3 (Steam Guard mobile authenticator code)
  deviceConfirmation, // 4 (approve on mobile)
  emailConfirmation, // 5
  unknown,
}

GuardType _guardFromInt(int v) {
  switch (v) {
    case 1:
      return GuardType.none;
    case 2:
      return GuardType.emailCode;
    case 3:
      return GuardType.deviceCode;
    case 4:
      return GuardType.deviceConfirmation;
    case 5:
      return GuardType.emailConfirmation;
    default:
      return GuardType.unknown;
  }
}

/// EAuthTokenPlatformType
const int _platformMobileApp = 3;

/// Result of a poll: either still pending, or tokens are ready.
class PollResult {
  final bool complete;
  final String? accessToken;
  final String? refreshToken;
  final String? accountName;
  final String? newChallengeUrl; // QR refreshed
  const PollResult({
    required this.complete,
    this.accessToken,
    this.refreshToken,
    this.accountName,
    this.newChallengeUrl,
  });
}

/// Drives Steam's modern `IAuthenticationService` login flow over plain HTTPS
/// (no SteamKit). Supports password login (direction-A QR too) and submitting
/// a Steam Guard code, then polling for the resulting JWT tokens.
class SteamAuthSession {
  final SteamApiClient api;

  int clientId = 0;
  int steamId = 0;
  Uint8List requestId = Uint8List(0);
  List<GuardType> allowedConfirmations = const [];
  String? qrChallengeUrl;

  SteamAuthSession(this.api);

  static const _iface = 'IAuthenticationService';

  /// Begins a credentials (username/password) auth session.
  Future<void> beginWithCredentials(String username, String password) async {
    // 1. RSA public key for the account.
    final rsaReq = ProtoWriter()..writeString(1, username);
    final rsaResp = (await api.callProtobuf(
      _iface,
      'GetPasswordRSAPublicKey',
      request: rsaReq,
      useGet: true,
    ))
        .parse();
    final mod = rsaResp[1]!.asString;
    final exp = rsaResp[2]!.asString;
    final timestamp = rsaResp[3]?.asInt ?? 0;

    final encryptedPassword = SteamRsa.encryptPassword(password, mod, exp);

    // 2. Begin the session.
    final req = ProtoWriter()
      ..writeString(1, 'AVA')
      ..writeString(2, username)
      ..writeString(3, encryptedPassword)
      ..writeUint64(4, timestamp)
      ..writeBool(5, false)
      ..writeVarint(6, _platformMobileApp)
      ..writeVarint(7, 1) // persistence: persistent
      ..writeMessage(9, _deviceDetails())
      ..writeString(8, 'Mobile');

    final fields = (await api.callProtobuf(
      _iface,
      'BeginAuthSessionViaCredentials',
      request: req,
    ))
        .parseAll();
    _consumeBeginResponse(fields);
  }

  /// Begins a QR (direction A) auth session; returns the challenge URL to render.
  Future<String> beginWithQr() async {
    final req = ProtoWriter()
      ..writeString(1, 'AVA')
      ..writeVarint(2, _platformMobileApp)
      ..writeMessage(3, _deviceDetails())
      ..writeString(4, 'Mobile');

    final fields = (await api.callProtobuf(
      _iface,
      'BeginAuthSessionViaQR',
      request: req,
    ))
        .parseAll();
    _consumeBeginResponse(fields, isQr: true);
    return qrChallengeUrl ?? '';
  }

  /// Parses a BeginAuthSession response.
  ///
  /// Credentials: 1=client_id, 2=request_id(bytes), 4=allowed_confirmations[],
  ///   5=steamid.
  /// QR:          1=client_id, 2=challenge_url(string), 3=request_id(bytes),
  ///   5=allowed_confirmations[], 7=version.
  void _consumeBeginResponse(List<ProtoField> fields, {bool isQr = false}) {
    final confs = <GuardType>[];
    final confField = isQr ? 5 : 4;
    for (final f in fields) {
      if (f.number == 1) {
        clientId = f.asInt;
      } else if (f.number == 2) {
        if (isQr) {
          qrChallengeUrl = f.asString;
        } else {
          requestId = f.bytes ?? Uint8List(0);
        }
      } else if (f.number == 3 && isQr) {
        requestId = f.bytes ?? Uint8List(0);
      } else if (f.number == confField && f.wireType == 2 && f.bytes != null) {
        // allowed_confirmations (repeated message): inner field 1 = type.
        final inner = ProtoReader(f.bytes!).parse();
        confs.add(_guardFromInt(inner[1]?.asInt ?? 0));
      } else if (f.number == 5 && !isQr && f.wireType == 0) {
        steamId = f.asInt; // credentials steamid
      }
    }
    if (confs.isNotEmpty) allowedConfirmations = confs;
    dlog('begin(${isQr ? 'qr' : 'creds'}): clientId=$clientId '
        'requestId=${requestId.length}B steamId=$steamId '
        'confs=${allowedConfirmations.map((e) => e.name).join(',')}');
  }

  /// Submits a Steam Guard code (email or device code).
  Future<void> submitSteamGuardCode(String code, GuardType type) async {
    final codeType = type == GuardType.emailCode ? 2 : 3;
    final req = ProtoWriter()
      ..writeUint64(1, clientId)
      ..writeFixed64(2, steamId) // steamid (fixed64!)
      ..writeString(3, code)
      ..writeVarint(4, codeType);
    try {
      await api.callProtobuf(
        _iface,
        'UpdateAuthSessionWithSteamGuardCode',
        request: req,
      );
    } on SteamApiException catch (e) {
      // DuplicateRequest (29): the code was already accepted for this session
      // (e.g. the same 30s TOTP was submitted moments ago). That's not a
      // failure — proceed to polling. Genuine errors (mismatched/expired code)
      // still propagate.
      if (e.eresult != _eresultDuplicateRequest) rethrow;
      dlog('guard code already accepted (DuplicateRequest) — proceed to poll');
    }
  }

  static const int _eresultDuplicateRequest = 29;

  /// Polls once for completion.
  Future<PollResult> poll() async {
    final req = ProtoWriter()
      ..writeUint64(1, clientId)
      ..writeBytes(2, requestId);
    final fields = (await api.callProtobuf(
      _iface,
      'PollAuthSessionStatus',
      request: req,
    ))
        .parse();

    final newClientId = fields[1]?.asInt ?? 0;
    if (newClientId != 0) clientId = newClientId;
    final accessToken = fields[4]?.asString;
    final refreshToken = fields[3]?.asString;
    final newChallenge = fields[2]?.asString;
    if (newChallenge != null && newChallenge.isNotEmpty) {
      qrChallengeUrl = newChallenge;
    }

    final complete = (refreshToken != null && refreshToken.isNotEmpty);
    return PollResult(
      complete: complete,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accountName: fields[6]?.asString,
      newChallengeUrl: newChallenge,
    );
  }

  /// Builds a [SessionData] once polling has produced tokens. For QR logins the
  /// steamid isn't in the begin/poll messages — it's the `sub` claim of the
  /// returned JWT, so fall back to decoding it from the token.
  SessionData toSessionData(PollResult result) {
    var sid = steamId;
    if (sid == 0) {
      sid = steamIdFromJwt(result.refreshToken) ??
          steamIdFromJwt(result.accessToken) ??
          0;
    }
    return SessionData(
      steamId: sid,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
  }

  /// Extracts the steamid (`sub`) from a Steam JWT access/refresh token.
  static int? steamIdFromJwt(String? jwt) {
    if (jwt == null || jwt.isEmpty) return null;
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (p.length % 4 != 0) {
        p += '=';
      }
      final payload =
          jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      return int.tryParse('${payload['sub']}');
    } catch (_) {
      return null;
    }
  }

  // device_details: matches the Steam mobile app (os_type AndroidUnknown,
  // gaming_device_type 528) so logins look like the official app.
  ProtoWriter _deviceDetails() => ProtoWriter()
    ..writeString(1, 'AVA') // device_friendly_name
    ..writeVarint(2, _platformMobileApp) // platform_type
    ..writeVarint(3, -500) // os_type = EOSType.AndroidUnknown
    ..writeVarint(4, 528); // gaming_device_type
}
