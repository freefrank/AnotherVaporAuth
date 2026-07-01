import 'dart:convert';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/steam_item.dart';

/// One page of inventory items plus pagination state.
class InventoryPage {
  final List<InventoryItem> items;
  final String? lastAssetId;
  final bool more;
  const InventoryPage(this.items, this.lastAssetId, this.more);
}

/// The account's games (with inventory) + the live wallet/fee constants, both
/// scraped from the inventory page.
class InventoryOverview {
  final List<InventoryGame> games;
  final WalletInfo wallet;
  const InventoryOverview(this.games, this.wallet);
}

/// Reads a Steam account's inventory (games list, wallet info, items) via the
/// community endpoints, authorized with the account's own session cookie.
class InventoryClient {
  final SteamApiClient api;
  InventoryClient(this.api);

  Map<String, String> _cookies(SteamGuardAccount a) => {
        'steamLoginSecure': '${a.steamId}||${a.session.accessToken ?? ''}',
        'mobileClient': 'android',
      };

  /// Fetches the game picker + wallet info by scraping the inventory page.
  Future<InventoryOverview> overview(SteamGuardAccount account) async {
    final html = await api.communityGetText(
      '/profiles/${account.steamId}/inventory/',
      cookies: _cookies(account),
    );
    final apps = _extractJsonObject(html, 'g_rgAppContextData');
    final walletJson = _extractJsonObject(html, 'g_rgWalletInfo');
    final wallet = walletJson != null
        ? WalletInfo.fromJson(walletJson)
        : WalletInfo.fallback;

    final games = <InventoryGame>[];
    if (apps != null) {
      apps.forEach((appid, raw) {
        final app = raw as Map<String, dynamic>;
        final contexts = (app['rgContexts'] as Map<String, dynamic>?) ?? {};
        contexts.forEach((cid, craw) {
          final ctx = craw as Map<String, dynamic>;
          final count = _asInt(ctx['asset_count']);
          if (count <= 0) return;
          games.add(InventoryGame(
            appid: int.tryParse(appid) ?? 0,
            contextId: cid,
            name: (app['name'] ?? '') as String,
            iconUrl: (app['icon'] ?? '') as String,
            itemCount: count,
          ));
        });
      });
    }
    games.sort((a, b) => b.itemCount.compareTo(a.itemCount));
    dlog('inventory overview: ${games.length} games, wallet=${wallet.currency}');
    return InventoryOverview(games, wallet);
  }

  /// Fetches one page of items for a game/context.
  Future<InventoryPage> items(
    SteamGuardAccount account,
    int appid,
    String contextId, {
    String? startAssetId,
    int count = 75,
  }) async {
    final json = await api.communityGetJson(
      '/inventory/${account.steamId}/$appid/$contextId',
      {
        'l': 'english',
        'count': '$count',
        'start_assetid': ?startAssetId,
      },
      cookies: _cookies(account),
    );
    final assets = (json['assets'] as List?) ?? const [];
    final descriptions = (json['descriptions'] as List?) ?? const [];
    // Index descriptions by classid_instanceid.
    final descByKey = <String, Map<String, dynamic>>{};
    for (final d in descriptions) {
      final m = d as Map<String, dynamic>;
      descByKey['${m['classid']}_${m['instanceid']}'] = m;
    }
    final items = <InventoryItem>[];
    for (final a in assets) {
      final m = a as Map<String, dynamic>;
      final d = descByKey['${m['classid']}_${m['instanceid']}'];
      if (d == null) continue;
      final feeApp = d['market_fee'];
      items.add(InventoryItem(
        appid: _asInt(m['appid']),
        contextId: '${m['contextid']}',
        assetId: '${m['assetid']}',
        classId: '${m['classid']}',
        instanceId: '${m['instanceid']}',
        amount: _asInt(m['amount']),
        marketHashName: (d['market_hash_name'] ?? '') as String,
        name: (d['name'] ?? '') as String,
        type: (d['type'] ?? '') as String,
        iconUrl: itemImageUrl(d['icon_url'] as String?),
        marketable: _asInt(d['marketable']) == 1,
        tradable: _asInt(d['tradable']) == 1,
        publisherFeePct: feeApp is num ? feeApp.toDouble() : null,
      ));
    }
    return InventoryPage(
      items,
      json['last_assetid'] as String?,
      json['more_items'] == 1 || json['more_items'] == true,
    );
  }

  /// Extracts a `var <name> = { … };` JSON object from page HTML by matching
  /// balanced braces (the values are JSON-parseable object literals).
  static Map<String, dynamic>? _extractJsonObject(String html, String name) {
    final marker = RegExp('$name\\s*=\\s*');
    final m = marker.firstMatch(html);
    if (m == null) return null;
    var i = m.end;
    if (i >= html.length || html[i] != '{') return null;
    var depth = 0;
    var inStr = false;
    String? quote;
    final start = i;
    for (; i < html.length; i++) {
      final c = html[i];
      if (inStr) {
        if (c == '\\') {
          i++;
        } else if (c == quote) {
          inStr = false;
        }
        continue;
      }
      if (c == '"' || c == "'") {
        inStr = true;
        quote = c;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          final raw = html.substring(start, i + 1);
          try {
            return jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
