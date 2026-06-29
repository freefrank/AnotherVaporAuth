/// Steam web session stored inside a maFile under the `Session` key.
///
/// The modern SteamAuth/SteamKit flow uses [steamId] + [accessToken] +
/// [refreshToken]. Older maFiles may carry extra cookie fields
/// (SessionID, SteamLoginSecure, WebCookie, OAuthToken…); those are preserved
/// verbatim in [extra] so re-saving a file never loses data.
class SessionData {
  int steamId;
  String? accessToken;
  String? refreshToken;

  /// Any other keys present in the original Session JSON (lossless round-trip).
  final Map<String, dynamic> extra;

  SessionData({
    this.steamId = 0,
    this.accessToken,
    this.refreshToken,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? <String, dynamic>{};

  bool get hasTokens =>
      (accessToken != null && accessToken!.isNotEmpty) ||
      (refreshToken != null && refreshToken!.isNotEmpty);

  static const _known = {'SteamID', 'AccessToken', 'RefreshToken'};

  factory SessionData.fromJson(Map<String, dynamic> json) {
    final extra = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!_known.contains(entry.key)) extra[entry.key] = entry.value;
    }
    return SessionData(
      steamId: _asInt(json['SteamID']),
      accessToken: json['AccessToken'] as String?,
      refreshToken: json['RefreshToken'] as String?,
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'SteamID': steamId,
        if (accessToken != null) 'AccessToken': accessToken,
        if (refreshToken != null) 'RefreshToken': refreshToken,
      };

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
