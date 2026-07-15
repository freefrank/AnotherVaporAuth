import 'dart:math';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/trade_offer.dart';
import 'qr_approval_client.dart' show MissingAccessTokenException;

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

  final _rand = Random.secure();
  String _newSessionId() {
    const hex = '0123456789abcdef';
    return List.generate(24, (_) => hex[_rand.nextInt(16)]).join();
  }

  Map<String, String> _cookies(SteamGuardAccount a, String sessionId) => {
        'steamLoginSecure': '${a.steamId}||${a.session.accessToken ?? ''}',
        'sessionid': sessionId,
        'mobileClient': 'android',
      };

  String _requireToken(SteamGuardAccount account) {
    final token = account.session.accessToken;
    if (token == null || token.isEmpty) {
      throw const MissingAccessTokenException();
    }
    return token;
  }

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
    final token = _requireToken(account);
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
    final token = _requireToken(account);
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
    _requireToken(account);
    final sid = _newSessionId();
    final json = await api.communityPostJson(
      '/tradeoffer/${offer.id}/accept',
      {
        'sessionid': sid,
        'serverid': '1',
        'tradeofferid': offer.id,
        'partner': '${offer.partnerSteamId}',
        'captcha': '',
      },
      cookies: _cookies(account, sid),
      referer: '${SteamApiClient.communityBase}/tradeoffer/${offer.id}/',
    );
    final err = json['strError'] as String?;
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

  /// Declines a received offer / cancels a sent one. Steam echoes the
  /// offer id on success; an empty body (decoded as {}) also counts —
  /// same contract as [MarketClient.isCancelSuccess].
  Future<bool> decline(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'decline');

  Future<bool> cancel(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'cancel');

  Future<bool> _writeOp(
      SteamGuardAccount account, String offerId, String op) async {
    _requireToken(account);
    final sid = _newSessionId();
    try {
      final json = await api.communityPostJson(
        '/tradeoffer/$offerId/$op',
        {'sessionid': sid},
        cookies: _cookies(account, sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/$offerId/',
      );
      if (json['needauth'] == true || json['needsauth'] == true) return false;
      if (json['strError'] != null) return false;
      dlog('tradeoffer $op $offerId -> ok');
      return true;
    } catch (e) {
      dlog('tradeoffer $op $offerId failed: $e');
      return false;
    }
  }
}
