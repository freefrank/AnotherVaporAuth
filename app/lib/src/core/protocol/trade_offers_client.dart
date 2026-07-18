import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/trade_offer.dart';
import 'community_session.dart';

/// Result of accepting a trade offer.
class TradeAcceptResult {
  final bool success;
  final bool needsMobileConfirmation;
  final String? message;
  const TradeAcceptResult({
    required this.success,
    this.needsMobileConfirmation = false,
    this.message,
  });
}

/// Trade offers for one account: list/count via the documented IEconService
/// JSON API (access_token auth), plus accept/decline/cancel via the community
/// `tradeoffer` endpoints (sessionid cookie/form auth).
class TradeOffersClient {
  final SteamApiClient api;
  TradeOffersClient(this.api);

  /// Safely narrows a decoded-JSON value to `Map<String, dynamic>`. A plain
  /// `as Map<String, dynamic>?` cast throws when the value is a
  /// `Map<dynamic, dynamic>` (e.g. an empty `{}` literal in tests, or some
  /// JSON decoders) — this converts instead of casting, and defaults to
  /// empty for anything else (missing key, null, non-map).
  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  /// Active (default) or historical offers, both directions, with
  /// descriptions joined. Historical == the "历史" segment.
  Future<TradeOffersPage> fetch(SteamGuardAccount account,
      {bool historical = false}) async {
    final token = requireAccessToken(account);
    final json = await api.apiGetJson(
      'IEconService',
      'GetTradeOffers',
      {
        'get_received_offers': '1',
        'get_sent_offers': '1',
        'get_descriptions': '1',
        'language': api.steamLanguage,
        'active_only': historical ? '0' : '1',
        'historical_only': historical ? '1' : '0',
      },
      accessToken: token,
    );
    final page = TradeOffersPage.fromResponse(_asMap(json['response']));
    dlog('trade offers: ${page.received.length} received, '
        '${page.sent.length} sent (historical=$historical)');
    return page;
  }

  /// Count of pending received offers (tab badge).
  Future<int> pendingReceivedCount(SteamGuardAccount account) async {
    final token = requireAccessToken(account);
    final json = await api.apiGetJson(
        'IEconService', 'GetTradeOffersSummary', const {},
        accessToken: token);
    final resp = _asMap(json['response']);
    final v = resp['pending_received_count'];
    return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  }

  /// Partner display info via the community miniprofile endpoint (no auth).
  /// Returns (personaName, avatarUrl); empty strings on failure.
  Future<(String, String)> miniProfile(int accountId) async {
    try {
      final json = await api.communityGetJson(
          '/miniprofile/$accountId/json', const {});
      return ((json['persona_name'] ?? '') as String,
          (json['avatar_url'] ?? '') as String);
    } catch (_) {
      return ('', '');
    }
  }

  /// Accepts a received offer. Steam replies `{tradeid, needs_mobile_confirmation}`
  /// on success or `{strError}` on failure. A mobileconf (type 2) usually
  /// follows — the caller routes the user to the confirmations tab.
  Future<TradeAcceptResult> accept(
      SteamGuardAccount account, TradeOffer offer) async {
    requireAccessToken(account);
    final sid = newCommunitySessionId();
    final Map<String, dynamic> json;
    try {
      json = await api.communityPostJson(
        '/tradeoffer/${offer.id}/accept',
        {
          'sessionid': sid,
          'serverid': '1',
          'tradeofferid': offer.id,
          'partner': '${offer.partnerSteamId}',
          'captcha': '',
        },
        cookies: communityCookies(account, sessionId: sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/${offer.id}/',
      );
    } on CommunityAuthException {
      // A stale session can also surface at the HTTP layer (401 or a redirect
      // to the login page) — same routing as the needauth JSON reply below.
      dlog('tradeoffer accept ${offer.id} -> needauth (http)');
      return const TradeAcceptResult(success: false, message: 'needauth');
    }
    // An expired session surfaces as needauth/needsauth — return a
    // recognizable message so the UI can route to re-login.
    if (json['needauth'] == true || json['needsauth'] == true) {
      dlog('tradeoffer accept ${offer.id} -> needauth');
      return const TradeAcceptResult(success: false, message: 'needauth');
    }
    final err = json['strError'] as String?;
    // Success requires a positive marker: tradeid echo or the mobileconf
    // flag. (Steam can also reply `needs_email_confirmation` for accounts
    // without a mobile authenticator — near-theoretical for AVA users, so
    // it's not handled, but noting the shape here for posterity.)
    final ok = err == null &&
        (json.containsKey('tradeid') ||
            json['needs_mobile_confirmation'] == true);
    dlog('tradeoffer accept ${offer.id} -> ok=$ok err=${err ?? '-'}');
    return TradeAcceptResult(
      success: ok,
      needsMobileConfirmation: json['needs_mobile_confirmation'] == true,
      message: err,
    );
  }

  /// Declines a received offer / cancels a sent one. Success must be
  /// positively confirmed by Steam echoing `{"tradeofferid": "..."}` — an
  /// empty body (expired session decoded as {}) must NOT read as "declined":
  /// telling the user a still-active phishing offer was declined is the
  /// worst failure mode for an authenticator app.
  Future<bool> decline(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'decline');

  Future<bool> cancel(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'cancel');

  Future<bool> _writeOp(
      SteamGuardAccount account, String offerId, String op) async {
    requireAccessToken(account);
    final sid = newCommunitySessionId();
    try {
      final json = await api.communityPostJson(
        '/tradeoffer/$offerId/$op',
        {'sessionid': sid},
        cookies: communityCookies(account, sessionId: sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/$offerId/',
      );
      if (json['needauth'] == true || json['needsauth'] == true) return false;
      if (json['strError'] != null) return false;
      if (json.containsKey('success') && json['success'] != true) return false;
      // Success must be positively confirmed by the offer-id echo — an empty
      // body (expired session decoded as {}) must NOT read as "declined".
      final ok = json['tradeofferid'] != null;
      dlog('tradeoffer $op $offerId -> '
          '${ok ? 'ok' : 'no confirmation in reply'}');
      return ok;
    } on CommunityAuthException {
      // HTTP-level stale session: propagate so the tab can point the user at
      // re-auth — swallowed as `false` it would read as a generic failure
      // with no sign-in cue, unlike accept()'s needauth mapping.
      rethrow;
    } catch (e) {
      dlog('tradeoffer $op $offerId failed: $e');
      return false;
    }
  }
}
