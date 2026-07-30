import '../crypto/secure_random.dart';
import '../models/steam_guard_account.dart';

/// Shared session plumbing for the steamcommunity.com / Web API clients:
/// the missing-access-token guard, the generated `sessionid`, and the mobile
/// cookie set. One definition instead of the per-client copies that used to
/// drift (trade offers, market, inventory, confirmations, family groups, QR).

/// Thrown when an operation needs to call a Steam Web API endpoint directly
/// but the account's session has no access token (e.g. a refresh-only
/// session that hasn't been renewed yet). Without this check the call would
/// silently go out with an empty access token, which fails in a confusing,
/// hard-to-diagnose way indistinguishable from a genuine server error.
class MissingAccessTokenException implements Exception {
  final String message;
  const MissingAccessTokenException(
      [this.message = 'account session has no access token']);
  @override
  String toString() => 'MissingAccessTokenException: $message';
}

/// Guards endpoints that authenticate with the access token alone (a refresh
/// token — [SessionData.hasTokens] without [SessionData.hasAccessToken] — is
/// not enough): returns the non-empty token, or fails clearly instead of
/// letting the call go out with an empty one.
String requireAccessToken(SteamGuardAccount account) {
  final token = account.session.accessToken;
  if (token == null || token.isEmpty) {
    throw const MissingAccessTokenException();
  }
  return token;
}

/// A fresh community `sessionid` value: 24 hex chars, cryptographically
/// random. Steam only checks that the cookie and the form/query field match,
/// so each write operation can mint its own.
String newCommunitySessionId() => secureRandomHex(24);

/// The mobile-client cookie set for steamcommunity.com requests.
///
/// Default shape (trade offers / market / inventory): `steamLoginSecure` +
/// `sessionid` (pass [sessionId] when the same value must also go into the
/// form body; omitted, a fresh one is minted) + `mobileClient`.
/// [confirmationVariant] is the mobileconf shape: no `sessionid` (those
/// requests are signed with the identity secret instead) but
/// `mobileClientVersion`, which the endpoint requires.
Map<String, String> communityCookies(
  SteamGuardAccount a, {
  String? sessionId,
  bool confirmationVariant = false,
}) =>
    {
      'steamLoginSecure': '${a.steamId}||${a.session.accessToken ?? ''}',
      if (!confirmationVariant) 'sessionid': sessionId ?? newCommunitySessionId(),
      'mobileClient': 'android',
      if (confirmationVariant) 'mobileClientVersion': '777777 3.6.4',
    };

/// The cookie set for `store.steampowered.com` requests.
///
/// Same `steamLoginSecure` shape as the community host (Steam's login is
/// unified across both), plus the `sessionid` that store write endpoints
/// cross-check against the form field. Deliberately *without* `mobileClient`:
/// the store serves a stripped mobile-app layout to that marker, and its ajax
/// endpoints are not part of it.
Map<String, String> storeCookies(SteamGuardAccount a, {String? sessionId}) => {
      'steamLoginSecure': '${a.steamId}||${a.session.accessToken ?? ''}',
      'sessionid': sessionId ?? newCommunitySessionId(),
    };
