// Steam economy models for the inventory + market feature.

const String _imageBase =
    'https://community.fastly.steamstatic.com/economy/image/';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is double) return v.toInt();
  return 0;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Live wallet / fee constants parsed from `g_rgWalletInfo` on a community page.
class WalletInfo {
  final int currency; // wallet_currency (23 = CNY, 1 = USD, …)
  final double steamFeePct; // wallet_fee_percent (0.05)
  final double publisherFeePct; // wallet_publisher_fee_percent_default (0.10)
  final int marketMinimum; // wallet_market_minimum (minor units)
  final int currencyIncrement; // wallet_currency_increment

  const WalletInfo({
    required this.currency,
    required this.steamFeePct,
    required this.publisherFeePct,
    required this.marketMinimum,
    required this.currencyIncrement,
  });

  /// Safe default (USD-like) used until the real wallet is fetched.
  static const fallback = WalletInfo(
    currency: 1,
    steamFeePct: 0.05,
    publisherFeePct: 0.10,
    marketMinimum: 1,
    currencyIncrement: 1,
  );

  /// Parses the `g_rgWalletInfo` object (values are strings).
  factory WalletInfo.fromJson(Map<String, dynamic> j) => WalletInfo(
        currency: _asInt(j['wallet_currency']),
        steamFeePct: _asDouble(j['wallet_fee_percent']),
        publisherFeePct: _asDouble(j['wallet_publisher_fee_percent_default']),
        marketMinimum: _asInt(j['wallet_market_minimum']),
        currencyIncrement:
            _asInt(j['wallet_currency_increment']).clamp(1, 1 << 30),
      );
}

/// A game + inventory context the account has items in (the game picker).
class InventoryGame {
  final int appid;
  final String contextId;
  final String name;
  final String iconUrl; // full URL
  final int itemCount;

  const InventoryGame({
    required this.appid,
    required this.contextId,
    required this.name,
    required this.iconUrl,
    required this.itemCount,
  });
}

/// One inventory item (asset merged with its description).
class InventoryItem {
  final int appid;
  final String contextId;
  final String assetId;
  final String classId;
  final String instanceId;
  final int amount;
  final String marketHashName;
  final String name;
  final String type;
  final String iconUrl; // full URL
  final bool marketable;
  final bool tradable;
  final double? publisherFeePct; // per-item override, if any

  const InventoryItem({
    required this.appid,
    required this.contextId,
    required this.assetId,
    required this.classId,
    required this.instanceId,
    required this.amount,
    required this.marketHashName,
    required this.name,
    required this.type,
    required this.iconUrl,
    required this.marketable,
    required this.tradable,
    this.publisherFeePct,
  });
}

/// The account's own active market listing.
class MarketListing {
  final String listingId;
  final int appid;
  final String marketHashName;
  final String name;
  final String iconUrl; // full URL
  final int buyerPrice; // what buyers pay (minor units)
  final int fee; // total fee (minor units)
  final int createdAt; // unix seconds
  final bool active;

  const MarketListing({
    required this.listingId,
    required this.appid,
    required this.marketHashName,
    required this.name,
    required this.iconUrl,
    required this.buyerPrice,
    required this.fee,
    required this.createdAt,
    required this.active,
  });

  /// Amount the seller receives = buyer price − fee.
  int get sellerReceives => buyerPrice - fee;

  factory MarketListing.fromJson(Map<String, dynamic> j) {
    final asset = (j['asset'] as Map<String, dynamic>?) ?? const {};
    return MarketListing(
      listingId: '${j['listingid']}',
      appid: _asInt(asset['appid']),
      marketHashName: (asset['market_hash_name'] ?? '') as String,
      name: (asset['name'] ?? asset['market_name'] ?? '') as String,
      iconUrl: _icon(asset['icon_url'] as String?),
      buyerPrice: _asInt(j['price']),
      fee: _asInt(j['fee']),
      createdAt: _asInt(j['time_created']),
      active: _asInt(j['active']) == 1,
    );
  }
}

/// Market price reference from `priceoverview` (localized strings).
class MarketPrice {
  final String? lowest;
  final String? median;
  final int? volume;
  const MarketPrice({this.lowest, this.median, this.volume});

  factory MarketPrice.fromJson(Map<String, dynamic> j) => MarketPrice(
        lowest: j['lowest_price'] as String?,
        median: j['median_price'] as String?,
        volume: j['volume'] is String
            ? int.tryParse((j['volume'] as String).replaceAll(',', ''))
            : (j['volume'] as int?),
      );
}

String _icon(String? raw) =>
    (raw == null || raw.isEmpty) ? '' : '$_imageBase$raw';

/// Exposed for the inventory/description merge.
String itemImageUrl(String? iconUrl) => _icon(iconUrl);
