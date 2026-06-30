import '../steam_totp.dart';
import 'session_data.dart';

/// A single Steam Guard account, the JSON payload of a `*.maFile`.
///
/// Field names mirror the C# `SteamGuardAccount` JsonProperty names exactly so
/// existing maFiles load and re-save losslessly. Unknown top-level keys are
/// preserved in [extra].
class SteamGuardAccount {
  String? sharedSecret; // shared_secret
  String? serialNumber; // serial_number
  String? revocationCode; // revocation_code
  String? uri; // uri
  int serverTime; // server_time
  String? accountName; // account_name
  String? tokenGid; // token_gid
  String? identitySecret; // identity_secret
  String? secret1; // secret_1
  int status; // status
  String? deviceId; // device_id
  bool fullyEnrolled; // fully_enrolled
  String? avatarUrl; // avatar_url — cached Steam profile avatar (full)
  SessionData session; // Session

  final Map<String, dynamic> extra;

  SteamGuardAccount({
    this.sharedSecret,
    this.serialNumber,
    this.revocationCode,
    this.uri,
    this.serverTime = 0,
    this.accountName,
    this.tokenGid,
    this.identitySecret,
    this.secret1,
    this.status = 0,
    this.deviceId,
    this.fullyEnrolled = false,
    this.avatarUrl,
    SessionData? session,
    Map<String, dynamic>? extra,
  })  : session = session ?? SessionData(),
        extra = extra ?? <String, dynamic>{};

  static const _known = {
    'shared_secret',
    'serial_number',
    'revocation_code',
    'uri',
    'server_time',
    'account_name',
    'token_gid',
    'identity_secret',
    'secret_1',
    'status',
    'device_id',
    'fully_enrolled',
    'avatar_url',
    'Session',
  };

  factory SteamGuardAccount.fromJson(Map<String, dynamic> json) {
    final extra = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!_known.contains(entry.key)) extra[entry.key] = entry.value;
    }
    final sessionJson = json['Session'];
    return SteamGuardAccount(
      sharedSecret: json['shared_secret'] as String?,
      serialNumber: json['serial_number'] as String?,
      revocationCode: json['revocation_code'] as String?,
      uri: json['uri'] as String?,
      serverTime: _asInt(json['server_time']),
      accountName: json['account_name'] as String?,
      tokenGid: json['token_gid'] as String?,
      identitySecret: json['identity_secret'] as String?,
      secret1: json['secret_1'] as String?,
      status: _asInt(json['status']),
      deviceId: json['device_id'] as String?,
      fullyEnrolled: json['fully_enrolled'] == true,
      avatarUrl: json['avatar_url'] as String?,
      session: sessionJson is Map<String, dynamic>
          ? SessionData.fromJson(sessionJson)
          : SessionData(),
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'shared_secret': sharedSecret,
        'serial_number': serialNumber,
        'revocation_code': revocationCode,
        'uri': uri,
        'server_time': serverTime,
        'account_name': accountName,
        'token_gid': tokenGid,
        'identity_secret': identitySecret,
        'secret_1': secret1,
        'status': status,
        'device_id': deviceId,
        'fully_enrolled': fullyEnrolled,
        'avatar_url': avatarUrl,
        'Session': session.toJson(),
      };

  /// Steam ID convenience accessor.
  int get steamId => session.steamId;

  /// Generates the current login code at the given Steam server [time].
  String generateCode(int time) {
    if (sharedSecret == null || sharedSecret!.isEmpty) {
      throw StateError('Account has no shared_secret');
    }
    return SteamTotp.generateAuthCode(sharedSecret!, time);
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
