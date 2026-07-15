import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/pending/offer_card.dart';
import 'package:ava/src/ui/pending/pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// getlist 回空、GetTradeOffers 回空的 fake —— 冒烟只验证骨架渲染。
/// [getlistCalls] 计数 mobileconf getlist 请求，用于断言 keep-alive 生效。
class _FakeApi extends SteamApiClient {
  int getlistCalls = 0;

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    if (path.contains('getlist')) getlistCalls++;
    return {'success': true, 'conf': []};
  }

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async =>
      {'response': {}};
}

/// Like [_FakeApi], but GetTradeOffers returns one received gift offer with a
/// joined description (empty icon_url → the card renders the no-image branch,
/// so the test never issues a network image request).
class _FakeApiWithOffer extends _FakeApi {
  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    if (method == 'GetTradeOffers') {
      return {
        'response': {
          'trade_offers_received': [
            {
              'tradeofferid': '7001',
              'accountid_other': 123,
              'trade_offer_state': 2,
              'items_to_receive': [
                {
                  'appid': 730,
                  'contextid': '2',
                  'assetid': '111',
                  'classid': '9',
                  'instanceid': '0',
                  'amount': '1',
                }
              ],
              'items_to_give': [],
              'time_created': 1752500000,
              'time_updated': 1752500000,
            }
          ],
          'descriptions': [
            {
              'appid': 730,
              'classid': '9',
              'instanceid': '0',
              'icon_url': '',
              'name': 'AK-47 | Redline',
              'market_hash_name': 'AK-47',
              'name_color': 'D2D2D2',
              'type': 'Rifle',
              'tradable': 1,
            }
          ],
        },
      };
    }
    return {'response': {}};
  }
}

/// [_FakeApiWithOffer] plus a scripted `communityPostJson` — records every
/// POST path and replies with [acceptReply], so the hold-to-accept flow can
/// be driven end to end without network.
class _FakeApiAcceptFlow extends _FakeApiWithOffer {
  final postPaths = <String>[];
  Map<String, dynamic> acceptReply = {
    'tradeid': '1',
    'needs_mobile_confirmation': true,
  };

  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    postPaths.add(path);
    return acceptReply;
  }
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

SteamGuardAccount _account() => SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );

Widget _app(SteamApiClient api, SteamGuardAccount account) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        skinSpecProvider.overrideWith(_NoSkinSpec.new),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: PendingScreen(account: account),
      ),
    );

void main() {
  testWidgets('pending screen renders both tabs and switches', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    expect(find.text('Confirmations'), findsOneWidget);
    expect(find.text('Trade offers'), findsOneWidget);
    final baseline = api.getlistCalls;

    // Switch away and back: the confirmations tab must be kept alive —
    // a rebuilt state would re-fetch (and re-sign) against Steam mobileconf.
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmations'));
    await tester.pumpAndSettle();
    expect(api.getlistCalls, baseline,
        reason: 'tab switching must not re-fetch confirmations (keep-alive)');
  });

  testWidgets('offer card renders, expands, shows gift banner', (tester) async {
    await tester.pumpWidget(_app(_FakeApiWithOffer(), _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    // 收起态：操作按钮不可见。
    expect(find.text('Hold to accept'), findsNothing);
    // 点卡片展开。
    await tester.tap(find.byType(OfferCard));
    await tester.pumpAndSettle();
    expect(find.text('Hold to accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Gift — you give nothing'), findsOneWidget);
  });

  testWidgets('hold-to-accept posts accept and hands off to confirmations',
      (tester) async {
    final api = _FakeApiAcceptFlow();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OfferCard));
    await tester.pumpAndSettle();
    final baseline = api.getlistCalls;

    // Drive the 900ms hold past completion.
    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Hold to accept')));
    // The tap recognizer only fires onTapDown after its ~100ms arena
    // deadline (the card sits in a scrollable), so give it a beat before
    // elapsing the 900ms hold.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(api.postPaths, contains('/tradeoffer/7001/accept'));
    expect(find.text('Offer accepted — confirm it in the Confirmations tab'),
        findsOneWidget);
    // Landed back on the confirmations tab (offstage text is not found).
    expect(find.text('No pending confirmations.'), findsOneWidget);
    expect(api.getlistCalls, greaterThan(baseline),
        reason: 'the handoff must re-fetch confirmations — the tab is '
            'keep-alive and would otherwise show stale data');
  });

  testWidgets('accept failure shows the error and stays on the offers tab',
      (tester) async {
    final api = _FakeApiAcceptFlow()..acceptReply = {'strError': 'oops'};
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OfferCard));
    await tester.pumpAndSettle();
    final baseline = api.getlistCalls;

    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Hold to accept')));
    // The tap recognizer only fires onTapDown after its ~100ms arena
    // deadline (the card sits in a scrollable), so give it a beat before
    // elapsing the 900ms hold.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(api.postPaths, contains('/tradeoffer/7001/accept'));
    expect(find.text('Action failed: oops'), findsOneWidget);
    // No tab switch, no confirmations refetch.
    expect(find.text('No pending confirmations.'), findsNothing);
    expect(api.getlistCalls, baseline);
  });
}
