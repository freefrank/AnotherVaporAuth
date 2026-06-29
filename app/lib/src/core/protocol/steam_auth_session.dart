import 'dart:typed_data';

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
      ..writeString(1, 'SDA Flutter')
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
      ..writeString(1, 'SDA Flutter')
      ..writeVarint(2, _platformMobileApp)
      ..writeMessage(3, _deviceDetails())
      ..writeString(4, 'Mobile');

    final fields = (await api.callProtobuf(
      _iface,
      'BeginAuthSessionViaQR',
      request: req,
    ))
        .parseAll();
    _consumeBeginResponse(fields, challengeField: 2);
    return qrChallengeUrl ?? '';
  }

  void _consumeBeginResponse(List<ProtoField> fields, {int? challengeField}) {
    final confs = <GuardType>[];
    for (final f in fields) {
      switch (f.number) {
        case 1:
          clientId = f.asInt;
          break;
        case 3:
          if (challengeField == null) {
            requestId = f.bytes ?? Uint8List(0);
          }
          break;
        case 2:
          if (challengeField == 2) {
            qrChallengeUrl = f.asString;
          } else {
            requestId = f.bytes ?? Uint8List(0);
          }
          break;
        case 4:
        case 5:
          // allowed_confirmations (repeated message): field varies QR vs creds.
          if (f.bytes != null && f.wireType == 2) {
            final inner = ProtoReader(f.bytes!).parse();
            final t = inner[1]?.asInt ?? 0;
            confs.add(_guardFromInt(t));
          } else if (f.number == 5) {
            steamId = f.asInt;
          }
          break;
        case 7:
          if (challengeField == 2) qrChallengeUrl ??= f.asString;
          break;
      }
    }
    // For credentials response, steamid is field 5 (uint64), handled above only
    // when not a message; ensure we captured it.
    for (final f in fields) {
      if (f.number == 5 && f.wireType == 0) steamId = f.asInt;
    }
    if (confs.isNotEmpty) allowedConfirmations = confs;
  }

  /// Submits a Steam Guard code (email or device code).
  Future<void> submitSteamGuardCode(String code, GuardType type) async {
    final codeType = type == GuardType.emailCode ? 2 : 3;
    final req = ProtoWriter()
      ..writeUint64(1, clientId)
      ..writeUint64(2, steamId)
      ..writeString(3, code)
      ..writeVarint(4, codeType);
    await api.callProtobuf(
      _iface,
      'UpdateAuthSessionWithSteamGuardCode',
      request: req,
    );
  }

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

  /// Builds a [SessionData] once polling has produced tokens.
  SessionData toSessionData(PollResult result) => SessionData(
        steamId: steamId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

  ProtoWriter _deviceDetails() => ProtoWriter()
    ..writeString(1, 'SDA Flutter')
    ..writeVarint(2, _platformMobileApp)
    ..writeVarint(3, -500); // EOSType Android
}
