import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart'
    show MissingAccessTokenException;
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/pending/offer_card.dart';
import 'package:ava/src/ui/pending/pending_screen.dart';
import 'package:ava/src/ui/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override(provider 覆写基类)在 riverpod 3 移到了 misc 入口。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// getlist 回空、GetTradeOffers 回空、protobuf 回空的 fake —— 冒烟只验证
/// 骨架渲染。[getlistCalls] 计数 mobileconf getlist 请求，用于断言 keep-alive 生效。
class _FakeApi extends SteamApiClient {
  int getlistCalls = 0;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    return ProtoReader(Uint8List(0)); // 空响应
  }

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
  bool throwOnPost = false;
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
    if (throwOnPost) throw Exception('network down');
    return acceptReply;
  }
}

/// Like [_FakeApi], but getlist returns one pending trade confirmation, so
/// the confirmations tab renders a card with its accept/reject actions.
class _FakeApiWithConf extends _FakeApi {
  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    if (path.contains('getlist')) getlistCalls++;
    return {
      'success': true,
      'conf': [
        {
          'id': '10',
          'nonce': '20',
          'type': 2,
          'type_name': 'Trade',
          'creator_id': '1',
          'headline': 'with friend_a',
          'summary': ['item'],
          'creation_time': 1752500000,
          'icon': '',
        }
      ],
    };
  }
}

/// First getlist replies needauth (→ ConfirmationAuthException), later calls
/// succeed; GenerateAccessTokenForApp hands out rotated tokens — drives the
/// confirmations tab's silent-refresh path end to end.
class _FakeApiNeedAuthOnce extends _FakeApi {
  bool _authFailed = false;

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    if (path.contains('getlist')) {
      getlistCalls++;
      if (!_authFailed) {
        _authFailed = true;
        return {'success': false, 'needauth': true};
      }
    }
    return {'success': true, 'conf': []};
  }

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GenerateAccessTokenForApp') {
      // Field numbers per session_manager.dart: 1=access, 2=refresh.
      final w = ProtoWriter()
        ..writeString(1, 'new-access')
        ..writeString(2, 'new-refresh');
      return ProtoReader(w.toBytes());
    }
    return super.callProtobuf(iface, method,
        request: request,
        accessToken: accessToken,
        useGet: useGet,
        version: version);
  }
}

/// First GetTradeOffers fails with a structural 401; the token exchange
/// hands out rotated tokens and the retry succeeds — drives the shared
/// session-retry mixin's refresh-then-retry path on the offers tab.
class _FakeApiOffers401Once extends _FakeApiWithOffer {
  int offerCalls = 0;
  int tokenCalls = 0;

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) {
    if (method == 'GetTradeOffers' && ++offerCalls == 1) {
      throw SteamApiException(2, 'HTTP 401', 'GetTradeOffers',
          httpStatus: 401);
    }
    return super.apiGetJson(iface, method, query,
        accessToken: accessToken, version: version);
  }

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GenerateAccessTokenForApp') {
      tokenCalls++;
      // Field numbers per session_manager.dart: 1=access, 2=refresh.
      final w = ProtoWriter()
        ..writeString(1, 'new-access')
        ..writeString(2, 'new-refresh');
      return ProtoReader(w.toBytes());
    }
    return super.callProtobuf(iface, method,
        request: request,
        accessToken: accessToken,
        useGet: useGet,
        version: version);
  }
}

/// GetTradeOffers always finds the session dead and the token exchange
/// yields nothing (empty reply) — the offers tab must land on the sign-in
/// affordance, not a retry loop or a raw exception dump.
class _FakeApiOffersSessionDead extends _FakeApi {
  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) {
    if (method == 'GetTradeOffers') {
      throw const MissingAccessTokenException();
    }
    return super.apiGetJson(iface, method, query,
        accessToken: accessToken, version: version);
    // base callProtobuf answers GenerateAccessTokenForApp with an empty
    // body → SessionManager.refresh returns false → the error surfaces.
  }
}

/// Two received offers whose miniprofile lookups each take [latency] —
/// pins that persona resolution is parallel (one latency window fills all
/// names; serial resolution would need one window per partner).
class _FakeApiSlowPersonas extends _FakeApi {
  static const latency = Duration(milliseconds: 300);

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    if (method == 'GetTradeOffers') {
      Map<String, dynamic> offer(String id, int partner) => {
            'tradeofferid': id,
            'accountid_other': partner,
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
          };
      return {
        'response': {
          'trade_offers_received': [offer('7001', 123), offer('7002', 456)],
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

  int _inFlight = 0;

  /// Peak concurrent miniprofile lookups: 2 ⇒ parallel, 1 ⇒ serial.
  int maxInFlightMiniProfiles = 0;

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    if (path.startsWith('/miniprofile/')) {
      _inFlight++;
      if (_inFlight > maxInFlightMiniProfiles) {
        maxInFlightMiniProfiles = _inFlight;
      }
      await Future<void>.delayed(latency);
      _inFlight--;
      return {
        'persona_name': path.contains('/123/') ? 'alice' : 'bob',
        'avatar_url': '',
      };
    }
    return super.communityGetJson(path, query, cookies: cookies);
  }
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

/// Hold-to-confirm toggle forced off (skips the settings-store load).
class _HoldOff extends HoldConfirmController {
  @override
  bool build() => false;
}

SteamGuardAccount _account() => SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );

Widget _app(SteamApiClient api, SteamGuardAccount account,
        {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        skinSpecProvider.overrideWith(_NoSkinSpec.new),
        ...overrides,
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
    // Family invites moved to the account long-press menu — no third tab.
    expect(find.text('Invites'), findsNothing);
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

  testWidgets('confirmation accept is a hold button by default',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApiWithConf(), _account()));
    await tester.pumpAndSettle();
    // 单条卡片上出现 HoldToConfirmButton（round 接受），拒绝仍是普通图标钮；
    // 批量栏"全部接受"也是 HoldToConfirmButton（pill）——共两个。
    expect(find.byType(HoldToConfirmButton), findsNWidgets(2));
  });

  testWidgets('hold toggle off: accept-all falls back to the dialog',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApiWithConf(), _account(),
        overrides: [holdConfirmProvider.overrideWith(_HoldOff.new)]));
    await tester.pumpAndSettle();
    // 批量栏退回普通按钮(pill 消失);卡片的 round 接受钮仍是
    // HoldToConfirmButton,但组件自身退化为普通点按 —— 故剩一个。
    expect(find.widgetWithText(HoldToConfirmButton, 'Accept all'),
        findsNothing);
    expect(find.byType(HoldToConfirmButton), findsOneWidget);
    // 点"全部接受"必须弹出确认弹窗(安全底线)。
    await tester.tap(find.text('Accept all'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('batch pill semantic activation routes through the dialog',
      (tester) async {
    final api = _FakeApiWithConf();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    final baseline = api.getlistCalls;

    // 辅助技术的合成点按没有长按门槛 —— 语义激活必须走弹窗二次确认,
    // 而不是直接执行(直接执行会在完成后 refresh,推高 getlistCalls)。
    tester.semantics.tap(find.semantics.byLabel('Accept all'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.getlistCalls, baseline,
        reason: 'semantic activation must not execute the batch directly');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.getlistCalls, baseline);
    handle.dispose();
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

  testWidgets(
      'silent token refresh persists the rotated tokens into the maFile',
      (tester) async {
    final api = _FakeApiNeedAuthOnce();
    final account = _account();
    final storage = MemoryStorageProvider();
    // A valid empty store, so the app controller bootstraps loaded (plain,
    // unencrypted) and persistSession has a store to write through.
    storage.files['manifest.json'] = jsonEncode(Manifest().toJson());

    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      skinSpecProvider.overrideWith(_NoSkinSpec.new),
      storageProvider.overrideWithValue(storage),
      timeAlignerProvider.overrideWithValue(() async {}),
      tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
    ]);
    addTearDown(container.dispose);
    // Bootstrap BEFORE the tab's initState fetch: the settings read is real
    // IO, and persistSession is a no-op while the store is still loading.
    // Seed the account into the store too — persistSession only writes
    // accounts that still exist (a removed account must not be resurrected
    // by a late token refresh), and the tab's standalone instance exercises
    // the graft-onto-loaded-instance path.
    await tester.runAsync(() async {
      await container.read(appControllerProvider.future);
      await container
          .read(appControllerProvider.notifier)
          .importMaFile(jsonEncode(account.toJson()));
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAvaTheme(AvaThemeVariant.neon),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: PendingScreen(account: account),
        ),
      ),
    );
    // Bounded settle loop instead of pumpAndSettle: the bootstrapped app
    // controller never fully settles, and the store's write-lock future was
    // created in the runAsync (real) zone — its completion only propagates
    // on real event-loop turns, so interleave real waits with pumps.
    final maFileName = '${account.session.steamId}.maFile';
    for (var i = 0;
        i < 10 &&
            !(storage.files[maFileName]?.contains('new-refresh') ?? false);
        i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }

    // needauth → token exchange → retry succeeded.
    expect(api.getlistCalls, 2);
    expect(account.session.refreshToken, 'new-refresh');
    // The regression: store.save() wrote only manifest.json — the renewed
    // (rotated!) tokens must land in the account payload itself.
    final maFile = storage.files['${account.session.steamId}.maFile'];
    expect(maFile, isNotNull,
        reason: 'the token renewal must persist the account payload');
    expect(maFile, contains('new-refresh'));
    expect(maFile, contains('new-access'));
  });

  testWidgets('accept exception shows error and does not wedge the tab',
      (tester) async {
    final api = _FakeApiAcceptFlow()..throwOnPost = true;
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OfferCard));
    await tester.pumpAndSettle();

    Future<void> hold() async {
      final gesture = await tester
          .startGesture(tester.getCenter(find.text('Hold to accept')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 1000));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await hold();
    expect(api.postPaths, hasLength(1));
    expect(find.textContaining('Action failed:'), findsOneWidget);

    // _busy must have been reset by the finally — a second hold must fire a
    // second POST instead of hitting a permanently disabled button.
    await hold();
    expect(api.postPaths, hasLength(2),
        reason: 'an accept exception must not leave _busy stuck at true');
  });

  testWidgets(
      'offers tab: a structural 401 triggers one silent token refresh and '
      'the retry renders the offers', (tester) async {
    final api = _FakeApiOffers401Once();
    final account = _account();
    await tester.pumpWidget(_app(api, account));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();

    expect(api.tokenCalls, 1,
        reason: 'the failed fetch must refresh the token exactly once');
    expect(api.offerCalls, 2, reason: 'refresh must be followed by a retry');
    // SessionManager patched the session in place with the rotated tokens.
    expect(account.session.accessToken, 'new-access');
    expect(account.session.refreshToken, 'new-refresh');
    // The retry succeeded — offer card, no error affordances.
    expect(find.byType(OfferCard), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
      'offers tab: a dead session (refresh cannot help) offers sign-in, '
      'not retry', (tester) async {
    await tester.pumpWidget(_app(_FakeApiOffersSessionDead(), _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();

    expect(
        find.text('Session expired — sign in again to refresh this account.'),
        findsOneWidget);
    expect(find.text('Log in'), findsOneWidget,
        reason: 'a dead session must route to interactive sign-in');
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('persona lookups run in parallel and all names land',
      (tester) async {
    final api = _FakeApiSlowPersonas();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();

    // Generous pumps so the delayed lookups complete under either shape —
    // a serial regression must fail on the concurrency assertion below,
    // not on a pending-timer teardown error.
    await tester.pump(_FakeApiSlowPersonas.latency * 2);
    await tester.pump(_FakeApiSlowPersonas.latency * 2);
    await tester.pump();

    expect(api.maxInFlightMiniProfiles, 2,
        reason: 'persona lookups must be issued concurrently — serially, '
            'N partners cost N round-trips before the last name fills in');
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });
}
