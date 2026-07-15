import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/trade_offer.dart';
import 'qr_approval_client.dart' show MissingAccessTokenException;

/// Trade offers for one account: list/count via the documented IEconService
/// JSON API (access_token auth). Accept/decline/cancel (community
/// `tradeoffer` endpoints) are added in a later task.
class TradeOffersClient {
  final SteamApiClient api;
  TradeOffersClient(this.api);

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
    return v is int ? v : int.tryParse('$v') ?? 0;
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
}
