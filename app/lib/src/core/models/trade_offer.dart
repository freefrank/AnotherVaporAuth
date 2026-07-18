// Trade offer models for IEconService/GetTradeOffers.
import '../json_coerce.dart';
import 'steam_item.dart' show itemImageUrl;

/// `trade_offer_state` values from IEconService/GetTradeOffers.
enum TradeOfferState {
  invalid, // 1
  active, // 2
  accepted, // 3
  countered, // 4
  expired, // 5
  canceled, // 6
  declined, // 7
  invalidItems, // 8
  needsConfirmation, // 9
  canceledBySecondFactor, // 10
  inEscrow, // 11
  unknown,
}

TradeOfferState _stateFrom(dynamic raw) {
  final v = asInt(raw);
  return (v >= 1 && v <= 11)
      ? TradeOfferState.values[v - 1]
      : TradeOfferState.unknown;
}

/// One asset in a trade offer, joined with its description (when present).
class TradeAsset {
  final int appid;
  final String contextId;
  final String assetId;
  final String classId;
  final String instanceId;
  final int amount;
  final String name;
  final String marketHashName;
  final String iconUrl;
  final String nameColor; // hex without '#', '' when absent
  final String type;

  const TradeAsset({
    required this.appid,
    required this.contextId,
    required this.assetId,
    required this.classId,
    required this.instanceId,
    required this.amount,
    this.name = '',
    this.marketHashName = '',
    this.iconUrl = '',
    this.nameColor = '',
    this.type = '',
  });

  factory TradeAsset.fromJson(Map<String, dynamic> json,
      Map<String, Map<String, dynamic>> descByKey) {
    // classid 只在单个 app 内唯一——跨游戏报价(CS2+TF2 混合很常见)必须带
    // appid 关联,否则可能渲染错物品名/图标/稀有度(node-steam-
    // tradeoffer-manager 同款键)。
    final d = descByKey[
        '${json['appid']}_${json['classid']}_${json['instanceid']}'];
    return TradeAsset(
      appid: asInt(json['appid']),
      contextId: '${json['contextid']}',
      assetId: '${json['assetid']}',
      classId: '${json['classid']}',
      instanceId: '${json['instanceid']}',
      amount: asInt(json['amount']),
      name: (d?['name'] ?? '') as String,
      marketHashName: (d?['market_hash_name'] ?? '') as String,
      iconUrl:
          d?['icon_url'] != null ? itemImageUrl(d!['icon_url'] as String?) : '',
      nameColor: (d?['name_color'] ?? '') as String,
      type: (d?['type'] ?? '') as String,
    );
  }
}

/// A trade offer as returned by IEconService/GetTradeOffers.
class TradeOffer {
  /// SteamID64 = accountid + this constant (individual/public/desktop).
  static const int steamId64Base = 76561197960265728;

  final String id;
  final int partnerAccountId;
  final String message;
  final TradeOfferState state;
  final bool isOurOffer;
  final List<TradeAsset> itemsToGive;
  final List<TradeAsset> itemsToReceive;
  final int timeCreated;
  final int timeUpdated;
  final int expirationTime;
  final int escrowEndDate;

  const TradeOffer({
    required this.id,
    required this.partnerAccountId,
    required this.message,
    required this.state,
    required this.isOurOffer,
    required this.itemsToGive,
    required this.itemsToReceive,
    required this.timeCreated,
    required this.timeUpdated,
    required this.expirationTime,
    required this.escrowEndDate,
  });

  int get partnerSteamId => steamId64Base + partnerAccountId;

  /// 对方白给：不需要我们付出任何物品。钓鱼报价常伪装成赠送，UI 不得因此
  /// 弱化接受门槛。
  bool get isGift => itemsToGive.isEmpty && itemsToReceive.isNotEmpty;

  /// 我们只给不收 —— 红色警告。
  bool get isOneSidedGive => itemsToReceive.isEmpty && itemsToGive.isNotEmpty;

  factory TradeOffer.fromJson(Map<String, dynamic> json,
      Map<String, Map<String, dynamic>> descByKey) {
    List<TradeAsset> assets(dynamic list) => ((list as List?) ?? const [])
        .map((e) => TradeAsset.fromJson(e as Map<String, dynamic>, descByKey))
        .toList();
    return TradeOffer(
      id: '${json['tradeofferid']}',
      partnerAccountId: asInt(json['accountid_other']),
      message: (json['message'] ?? '') as String,
      state: _stateFrom(json['trade_offer_state']),
      isOurOffer: json['is_our_offer'] == true,
      itemsToGive: assets(json['items_to_give']),
      itemsToReceive: assets(json['items_to_receive']),
      timeCreated: asInt(json['time_created']),
      timeUpdated: asInt(json['time_updated']),
      expirationTime: asInt(json['expiration_time']),
      escrowEndDate: asInt(json['escrow_end_date']),
    );
  }
}

/// The parsed `response` object of GetTradeOffers.
class TradeOffersPage {
  final List<TradeOffer> received;
  final List<TradeOffer> sent;
  const TradeOffersPage(this.received, this.sent);

  factory TradeOffersPage.fromResponse(Map<String, dynamic> response) {
    final descByKey = <String, Map<String, dynamic>>{};
    for (final d in (response['descriptions'] as List?) ?? const []) {
      final m = d as Map<String, dynamic>;
      descByKey['${m['appid']}_${m['classid']}_${m['instanceid']}'] = m;
    }
    List<TradeOffer> offers(String key) =>
        ((response[key] as List?) ?? const [])
            .map((e) =>
                TradeOffer.fromJson(e as Map<String, dynamic>, descByKey))
            .toList();
    return TradeOffersPage(
        offers('trade_offers_received'), offers('trade_offers_sent'));
  }
}
