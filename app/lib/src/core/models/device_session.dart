/// A single logged-in device / session for a Steam account, decoded from one
/// `CAuthentication_RefreshToken_Enumerate_Response.RefreshTokenDescription`.
///
/// Field numbers follow SteamDatabase/Protobufs
/// `steam/steammessages_auth.steamclient.proto` — verbatim-checked; see
/// `docs/specs/device-sessions.md` 协议事实 table.
class DeviceSession {
  /// `token_id` (fixed64) — stable id of this refresh token. Needed later to
  /// revoke a specific device; kept as a string because it is a 64-bit handle,
  /// not an arithmetic value.
  final String tokenId;

  /// `token_description` — Steam's human label ("Firefox on Windows", the
  /// device name the client reported at login…). May be empty.
  final String description;

  /// `time_updated` (unix seconds) — last time this token was refreshed.
  final int timeUpdated;

  /// `platform_type` — 0 unknown, 1 SteamClient, 2 WebBrowser, 3 MobileApp.
  final int platformType;

  /// `logged_in` — whether the session is currently active.
  final bool loggedIn;

  /// `last_seen` usage event, best-effort (may be absent).
  final DeviceUsage? lastSeen;

  const DeviceSession({
    required this.tokenId,
    required this.description,
    required this.timeUpdated,
    required this.platformType,
    required this.loggedIn,
    this.lastSeen,
  });
}

/// One `TokenUsageEvent` (first_seen / last_seen): when + roughly where a
/// token was used. IP is intentionally dropped — the coarse geo (city/country)
/// is what a user recognises, and holding the IP buys nothing here.
class DeviceUsage {
  final int time; // unix seconds
  final String country;
  final String state;
  final String city;

  const DeviceUsage({
    this.time = 0,
    this.country = '',
    this.state = '',
    this.city = '',
  });

  /// "City, State, Country" with the empty parts dropped.
  String get locationLabel =>
      [city, state, country].where((s) => s.isNotEmpty).join(', ');
}

/// The full device list plus which entry is *this* device (the token the
/// request authenticated with), so the UI can badge "current" and refuse to
/// offer self-revocation.
class DeviceSessionList {
  final List<DeviceSession> devices;

  /// `requesting_token` (fixed64) — the token_id of the calling device, or
  /// empty when Steam didn't echo it.
  final String requestingTokenId;

  const DeviceSessionList({
    required this.devices,
    this.requestingTokenId = '',
  });

  bool isCurrent(DeviceSession d) =>
      requestingTokenId.isNotEmpty && d.tokenId == requestingTokenId;
}
