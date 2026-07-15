import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/trade_offer.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart'
    show MissingAccessTokenException;
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake API：记录调用并回放响应。apiGetJson / communityPostJson 双通道。
class _FakeApi extends SteamApiClient {
  Map<String, dynamic> apiResponse = const {};
  Map<String, dynamic> postResponse = const {};
  Map<String, dynamic> getResponse = const {};
  String? lastMethod;
  Map<String, dynamic>? lastQuery;
  String? lastPostPath;
  Map<String, dynamic>? lastForm;
  Map<String, String>? lastCookies;
  String? lastReferer;
  String? lastGetPath;

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    lastMethod = '$iface/$method';
    lastQuery = {...query, 'access_token': ?accessToken};
    return apiResponse;
  }

  bool throwOnPost = false;

  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    lastPostPath = path;
    lastForm = form;
    lastCookies = cookies;
    lastReferer = referer;
    if (throwOnPost) throw Exception('network down');
    return postResponse;
  }

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    lastGetPath = path;
    return getResponse;
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: 'tok',
        refreshToken: 'r',
      ),
    );

void main() {
  group('fetch', () {
    test('active received+sent uses documented params and parses', () async {
      final api = _FakeApi()
        ..apiResponse = {
          'response': {
            'trade_offers_received': [
              {'tradeofferid': '1', 'accountid_other': 5, 'trade_offer_state': 2,
               'items_to_receive': [
                 {'appid': 1, 'contextid': '2', 'assetid': '3',
                  'classid': '9', 'instanceid': '0', 'amount': '1'}
               ]},
            ],
          },
        };
      final page = await TradeOffersClient(api).fetch(_account());
      expect(page.received, hasLength(1));
      expect(api.lastMethod, 'IEconService/GetTradeOffers');
      expect(api.lastQuery!['get_received_offers'], '1');
      expect(api.lastQuery!['get_sent_offers'], '1');
      expect(api.lastQuery!['get_descriptions'], '1');
      expect(api.lastQuery!['active_only'], '1');
      expect(api.lastQuery!['access_token'], 'tok');
    });

    test('historical fetch flips the flags', () async {
      final api = _FakeApi()..apiResponse = {'response': {}};
      await TradeOffersClient(api).fetch(_account(), historical: true);
      expect(api.lastQuery!['active_only'], '0');
      expect(api.lastQuery!['historical_only'], '1');
    });

    test('missing access token throws before any network call', () async {
      final api = _FakeApi();
      final noToken = SteamGuardAccount(
          session: SessionData(steamId: 1, refreshToken: 'r'));
      expect(() => TradeOffersClient(api).fetch(noToken),
          throwsA(isA<MissingAccessTokenException>()));
      expect(api.lastMethod, isNull);
    });
  });

  test('summary returns pending received count', () async {
    final api = _FakeApi()
      ..apiResponse = {'response': {'pending_received_count': 3,
                                    'new_received_count': 1}};
    expect(await TradeOffersClient(api).pendingReceivedCount(_account()), 3);
    expect(api.lastMethod, 'IEconService/GetTradeOffersSummary');
  });

  test('summary tolerates a double pending_received_count', () async {
    final api = _FakeApi()
      ..apiResponse = {'response': {'pending_received_count': 3.0}};
    expect(await TradeOffersClient(api).pendingReceivedCount(_account()), 3);
  });

  group('miniProfile', () {
    test('happy path parses persona and avatar', () async {
      final api = _FakeApi()
        ..getResponse = {
          'persona_name': 'Bob',
          'avatar_url': 'http://x/a.jpg',
        };
      final result = await TradeOffersClient(api).miniProfile(123);
      expect(result, ('Bob', 'http://x/a.jpg'));
      expect(api.lastGetPath, '/miniprofile/123/json');
    });

    test('malformed response falls back to empty strings', () async {
      final api = _FakeApi()..getResponse = {};
      final result = await TradeOffersClient(api).miniProfile(123);
      expect(result, ('', ''));
    });
  });

  group('write ops (community tradeoffer endpoints)', () {
    test('accept posts sessionid+partner with referer, detects mobileconf', () async {
      final api = _FakeApi()
        ..postResponse = {'tradeid': '900', 'needs_mobile_confirmation': true};
      final offer = TradeOffer(
        id: '7001', partnerAccountId: 123, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isTrue);
      expect(r.needsMobileConfirmation, isTrue);
      expect(api.lastPostPath, '/tradeoffer/7001/accept');
      expect(api.lastForm!['tradeofferid'], '7001');
      expect(api.lastForm!['partner'], '${76561197960265728 + 123}');
      expect(api.lastForm!['serverid'], '1');
      // sessionid 必须同时进 form 和 cookie 且一致。
      expect(api.lastForm!['sessionid'], api.lastCookies!['sessionid']);
      expect(api.lastReferer, 'https://steamcommunity.com/tradeoffer/7001/');
    });

    test('accept surfaces strError as failure', () async {
      final api = _FakeApi()..postResponse = {'strError': 'trade banned'};
      final offer = TradeOffer(
        id: '1', partnerAccountId: 1, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isFalse);
      expect(r.message, 'trade banned');
    });

    test('decline and cancel post to their endpoints', () async {
      final api = _FakeApi()..postResponse = {'tradeofferid': '7001'};
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isTrue);
      expect(api.lastPostPath, '/tradeoffer/7001/decline');
      expect(await TradeOffersClient(api).cancel(_account(), '7002'), isTrue);
      expect(api.lastPostPath, '/tradeoffer/7002/cancel');
      expect(api.lastForm!['sessionid'], isNotEmpty);
    });

    test('decline treats an empty body (expired session) as failure', () async {
      // 401/302 → 空 body → communityPostJson 解码为 {}。没有 tradeofferid
      // 回显就不能宣称"已拒绝"——钓鱼报价可能仍然活跃。
      final api = _FakeApi()..postResponse = {};
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isFalse);
    });

    test('decline treats explicit success:false as failure', () async {
      final api = _FakeApi()..postResponse = {'success': false};
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isFalse);
    });

    test('decline treats needauth as failure', () async {
      final api = _FakeApi()
        ..postResponse = {'needauth': true, 'tradeofferid': '7001'};
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isFalse);
    });

    test('decline returns false when the request throws', () async {
      final api = _FakeApi()..throwOnPost = true;
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isFalse);
    });

    test('accept treats an empty body (expired session) as failure', () async {
      final api = _FakeApi()..postResponse = {};
      final offer = TradeOffer(
        id: '1', partnerAccountId: 1, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isFalse);
    });

    test('accept surfaces needauth as a recognizable failure', () async {
      final api = _FakeApi()..postResponse = {'needauth': true};
      final offer = TradeOffer(
        id: '1', partnerAccountId: 1, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isFalse);
      expect(r.message, 'needauth');
    });
  });
}
