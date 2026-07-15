import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart'
    show MissingAccessTokenException;
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake API：记录调用并回放响应。apiGetJson / communityPostJson 双通道。
class _FakeApi extends SteamApiClient {
  Map<String, dynamic> apiResponse = const {};
  Map<String, dynamic> postResponse = const {};
  String? lastMethod;
  Map<String, dynamic>? lastQuery;
  String? lastPostPath;
  Map<String, dynamic>? lastForm;
  Map<String, String>? lastCookies;
  String? lastReferer;

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
    return postResponse;
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
}
