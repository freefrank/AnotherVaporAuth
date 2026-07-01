import 'dart:math';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/steam_item.dart';

/// Result of listing an item for sale.
class SellResult {
  final bool success;
  final bool requiresConfirmation;
  final String? message;
  const SellResult({
    required this.success,
    this.requiresConfirmation = false,
    this.message,
  });
}

/// Steam Community Market operations for one account: price lookup, listing an
/// item for sale, listing management. All writes are POST form bodies with a
/// generated `sessionid` (sent as both a cookie and a form field) and a Referer.
class MarketClient {
  final SteamApiClient api;
  MarketClient(this.api);

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

  String _inventoryReferer(SteamGuardAccount a) =>
      '${SteamApiClient.communityBase}/profiles/${a.steamId}/inventory';

  /// Historical sale prices for the item (for a trend sparkline). Returns the
  /// most recent [points] price values, or empty on failure. Requires login.
  Future<List<double>> priceHistory(
      SteamGuardAccount account, int appid, String marketHashName,
      {int points = 60}) async {
    final sid = _newSessionId();
    try {
      final json = await api.communityGetJson(
        '/market/pricehistory/',
        {'appid': '$appid', 'market_hash_name': marketHashName},
        cookies: _cookies(account, sid),
      );
      if (json['success'] != true) return const [];
      final prices = (json['prices'] as List?) ?? const [];
      final values = <double>[];
      for (final p in prices) {
        if (p is List && p.length >= 2 && p[1] is num) {
          values.add((p[1] as num).toDouble());
        }
      }
      return values.length > points
          ? values.sublist(values.length - points)
          : values;
    } catch (_) {
      return const [];
    }
  }

  /// Reference price for an item (localized strings). Null on failure/rate-limit.
  Future<MarketPrice?> priceOverview(
      int appid, String marketHashName, int currency) async {
    try {
      final json = await api.communityGetJson('/market/priceoverview/', {
        'appid': '$appid',
        'currency': '$currency',
        'market_hash_name': marketHashName,
      });
      if (json['success'] != true) return null;
      return MarketPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Lists [item] for sale. [priceReceive] is the amount the seller receives, in
  /// the wallet's minor units. On success Steam usually needs a mobile
  /// confirmation to finalize the listing.
  Future<SellResult> sell(
      SteamGuardAccount account, InventoryItem item, int priceReceive,
      {String? assetId}) async {
    final sid = _newSessionId();
    final json = await api.communityPostJson(
      '/market/sellitem/',
      {
        'sessionid': sid,
        'appid': '${item.appid}',
        'contextid': item.contextId,
        'assetid': assetId ?? item.assetId,
        'amount': '1',
        'price': '$priceReceive',
      },
      cookies: _cookies(account, sid),
      referer: _inventoryReferer(account),
    );
    final ok = json['success'] == true;
    final needsConf = json['requires_confirmation'] == 1 ||
        json['needs_mobile_confirmation'] == true;
    dlog('sellitem ${item.marketHashName} price=$priceReceive '
        '-> success=$ok conf=$needsConf');
    return SellResult(
      success: ok,
      requiresConfirmation: needsConf,
      message: json['message'] as String?,
    );
  }

  /// The account's active listings.
  Future<List<MarketListing>> myListings(SteamGuardAccount account,
      {int count = 100}) async {
    final sid = _newSessionId();
    final json = await api.communityGetJson(
      '/market/mylistings/',
      {'norender': '1', 'count': '$count'},
      cookies: _cookies(account, sid),
    );
    final listings = (json['listings'] as List?) ?? const [];
    return listings
        .map((e) => MarketListing.fromJson(e as Map<String, dynamic>))
        .where((l) => l.active)
        .toList();
  }

  /// Cancels/removes an active listing.
  Future<bool> cancel(SteamGuardAccount account, String listingId) async {
    final sid = _newSessionId();
    try {
      await api.communityPostJson(
        '/market/removelisting/$listingId',
        {'sessionid': sid},
        cookies: _cookies(account, sid),
        referer: '${SteamApiClient.communityBase}/market/',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
