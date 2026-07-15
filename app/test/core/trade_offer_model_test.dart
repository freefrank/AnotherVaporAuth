import 'dart:convert';

import 'package:ava/src/core/models/trade_offer.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = '''
{"response": {
  "trade_offers_received": [
    {"tradeofferid": "7001", "accountid_other": 123, "message": "hi",
     "expiration_time": 1800000000, "trade_offer_state": 2,
     "items_to_give": [],
     "items_to_receive": [
       {"appid": 730, "contextid": "2", "assetid": "111", "classid": "9", "instanceid": "0", "amount": "1"}
     ],
     "is_our_offer": false, "time_created": 1752500000, "time_updated": 1752500000,
     "escrow_end_date": 0, "confirmation_method": 0}
  ],
  "trade_offers_sent": [
    {"tradeofferid": "7002", "accountid_other": 456, "trade_offer_state": 9,
     "items_to_give": [
       {"appid": 730, "contextid": "2", "assetid": "222", "classid": "8", "instanceid": "0", "amount": "1"}
     ],
     "items_to_receive": [],
     "is_our_offer": true, "time_created": 1752400000, "time_updated": 1752400000,
     "escrow_end_date": 1753000000, "confirmation_method": 2}
  ],
  "descriptions": [
    {"appid": 730, "classid": "9", "instanceid": "0", "icon_url": "abc",
     "name": "AK-47 | Redline", "market_hash_name": "AK-47 | Redline (Field-Tested)",
     "name_color": "D2D2D2", "type": "Rifle", "tradable": 1},
    {"appid": 730, "classid": "8", "instanceid": "0", "icon_url": "def",
     "name": "Glock", "market_hash_name": "Glock", "name_color": "", "type": "Pistol", "tradable": 1}
  ]
}}
''';

void main() {
  final page = TradeOffersPage.fromResponse(
      jsonDecode(_fixture)['response'] as Map<String, dynamic>);

  test('received/sent split and description join', () {
    expect(page.received, hasLength(1));
    expect(page.sent, hasLength(1));
    final r = page.received.single;
    expect(r.id, '7001');
    expect(r.itemsToReceive.single.name, 'AK-47 | Redline');
    expect(r.itemsToReceive.single.iconUrl, isNotEmpty);
    expect(r.itemsToReceive.single.nameColor, 'D2D2D2');
  });

  test('gift and one-sided detection', () {
    expect(page.received.single.isGift, isTrue);      // 只收不给
    expect(page.received.single.isOneSidedGive, isFalse);
    expect(page.sent.single.isOneSidedGive, isTrue);  // 只给不收
  });

  test('partner steamid64 derived from accountid_other', () {
    expect(page.received.single.partnerSteamId, 76561197960265728 + 123);
  });

  test('state and escrow parse', () {
    expect(page.received.single.state, TradeOfferState.active);
    expect(page.sent.single.state, TradeOfferState.needsConfirmation);
    expect(page.sent.single.escrowEndDate, 1753000000);
  });

  test('missing description keeps asset with empty name', () {
    final noDesc = TradeOffersPage.fromResponse(jsonDecode('''
      {"trade_offers_received": [{"tradeofferid": "1", "accountid_other": 1,
        "trade_offer_state": 2,
        "items_to_receive": [{"appid": 1, "contextid": "2", "assetid": "3",
          "classid": "99", "instanceid": "0", "amount": "1"}]}]}
    ''') as Map<String, dynamic>);
    expect(noDesc.received.single.itemsToReceive.single.name, isEmpty);
  });
}
