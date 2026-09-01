import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:dio/dio.dart';
// fake_async ships (pinned) via flutter_test's dependency tree.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/entitlement_mint.dart';
import '../support/temp_dir.dart';

class _FakeApi implements EntitlementApi {
  String? nextToken;
  Object? nextError;
  int refreshCalls = 0;
  String? lastRefreshToken;
  String? lastDeviceId;

  Future<String> _reply() async {
    if (nextError != null) throw nextError!;
    return nextToken!;
  }

  @override
  Future<String> refresh(String token, String deviceId) {
    refreshCalls++;
    lastRefreshToken = token;
    lastDeviceId = deviceId;
    return _reply();
  }

  @override
  Future<String> verifyPlay(
          {required String idToken,
          required String purchaseToken,
          required String deviceId,
          required String deviceClass}) =>
      _reply();

  @override
  Future<String> redeemAfdian(
          {required String orderNo,
          required String deviceId,
          required String deviceClass}) =>
      _reply();

  @override
  Future<String> redeemBeta(
          {required String code,
          required String deviceId,
          required String deviceClass}) =>
      _reply();

  @override
  Future<String> claimVip(
          {required String deviceId, required String deviceClass}) =>
      _reply();

  @override
  Future<EntitlementStatus> status(String token) async {
    if (nextError != null) throw nextError!;
    throw UnimplementedError('status not stubbed');
  }
}

/// Serves one canned HTTP reply so DioEntitlementApi's wire parsing runs
/// against real dio plumbing (no sockets).
class _CannedAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  RequestOptions? last;
  _CannedAdapter(this.status, this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

DioEntitlementApi _cannedApi(_CannedAdapter adapter) =>
    DioEntitlementApi(
        dio: Dio(BaseOptions(
          baseUrl: 'https://canned.invalid',
          validateStatus: (_) => true,
        ))
          ..httpClientAdapter = adapter);

void main() {
  final mint = EntitlementMint();
  final now = DateTime.utc(2026, 7, 15, 12);

  late Directory tmp;
  late MemoryStorageProvider storage;
  late _FakeApi api;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ava_entitlement');
    storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
    api = _FakeApi();
  });

  tearDown(() => deleteTempDirSync(tmp));

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      storageProvider.overrideWithValue(storage),
      entitlementApiProvider.overrideWithValue(api),
      entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle(ProviderContainer c, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  group('deviceIdProvider', () {
    test('generates once and stays stable across containers', () async {
      final first = await makeContainer().read(deviceIdProvider.future);
      expect(first, hasLength(32));
      final second = await makeContainer().read(deviceIdProvider.future);
      expect(second, first);
    });
  });

  group('EntitlementTokenController', () {
    test('adopt verifies, persists and reloads in a fresh container',
        () async {
      final c1 = makeContainer();
      final ok = await c1
          .read(entitlementTokenProvider.notifier)
          .adopt(mint.mint(now: now));
      expect(ok, isTrue);
      expect(c1.read(proStatusProvider), ProStatus.pro);

      final c2 = makeContainer();
      c2.read(entitlementTokenProvider);
      await settle(c2, () => c2.read(entitlementTokenProvider) != null);
      expect(c2.read(entitlementTokenProvider)?.subject, 'user-1');
      expect(c2.read(proStatusProvider), ProStatus.pro);
    });

    test('adopt never trades a longer entitlement for a shorter one',
        () async {
      // The on-device 2026-08-16 case: rewarded VIP until +3d, then a
      // subscribe under a Play license tester hands back a token whose
      // period end is minutes away. Buying Pro must not shorten Pro.
      final c = makeContainer();
      final notifier = c.read(entitlementTokenProvider.notifier);
      await notifier.adopt(
          mint.mint(now: now, tier: 'vip', pro: now.add(const Duration(days: 3))));
      final ok = await notifier.adopt(
          mint.mint(now: now, pro: now.add(const Duration(minutes: 5))));
      expect(ok, isTrue, reason: 'the action itself still succeeded');
      expect(c.read(entitlementTokenProvider)?.tier.name, 'vip',
          reason: 'the 3-day VIP outlives the 5-minute sub window');

      // And the extreme: a lifetime beta token loses to nothing.
      await notifier.adopt(mint.mint(now: now, chan: 'beta', lifetime: true));
      await notifier.adopt(
          mint.mint(now: now, pro: now.add(const Duration(days: 30))));
      expect(c.read(entitlementTokenProvider)?.proUntil, isNull,
          reason: 'lifetime survives a 30-day sub token');
    });

    test('adopt upgrades to a longer entitlement and past ones yield',
        () async {
      final c = makeContainer();
      final notifier = c.read(entitlementTokenProvider.notifier);
      await notifier.adopt(
          mint.mint(now: now, pro: now.add(const Duration(minutes: 5))));
      await notifier.adopt(
          mint.mint(now: now, tier: 'vip', pro: now.add(const Duration(days: 3))));
      expect(c.read(entitlementTokenProvider)?.tier.name, 'vip',
          reason: 'longer replaces shorter');
    });

    test('adopt rejects garbage and keeps the previous token', () async {
      final c = makeContainer();
      final notifier = c.read(entitlementTokenProvider.notifier);
      await notifier.adopt(mint.mint(now: now));
      expect(await notifier.adopt('not-a-token'), isFalse);
      expect(c.read(entitlementTokenProvider), isNotNull);
    });

    test('a token needing refresh triggers a refresh on load', () async {
      // Store a token past its exp (inside grace) directly, as if the app
      // had been offline for two days.
      final stale = mint.mint(
          now: now, exp: now.subtract(const Duration(days: 2)));
      final seed = makeContainer();
      await seed
          .read(settingsStoreProvider)
          .saveEntitlementToken(stale);
      api.nextToken = mint.mint(now: now);

      final c = makeContainer();
      c.read(entitlementTokenProvider);
      await settle(c, () => api.refreshCalls > 0);
      await settle(
          c,
          () =>
              c.read(entitlementTokenProvider)?.expiresAt.isAfter(now) ??
              false);
      expect(api.refreshCalls, 1);
      expect(c.read(proStatusProvider), ProStatus.pro);
    });

    test('terminal 403 on refresh drops the token and persists the drop',
        () async {
      final c = makeContainer();
      final notifier = c.read(entitlementTokenProvider.notifier);
      await notifier.adopt(mint.mint(now: now));
      api.nextError = EntitlementApiException(403, 'device_revoked');

      await notifier.refreshNow();
      expect(c.read(entitlementTokenProvider), isNull);
      expect(c.read(proStatusProvider), ProStatus.free);
      expect(
          await c.read(settingsStoreProvider).loadEntitlementToken(), isNull);
    });

    test('network failure on refresh keeps the token (grace covers it)',
        () async {
      final c = makeContainer();
      final notifier = c.read(entitlementTokenProvider.notifier);
      await notifier.adopt(mint.mint(now: now));
      api.nextError = Exception('socket');

      await notifier.refreshNow();
      expect(c.read(entitlementTokenProvider), isNotNull);
      expect(c.read(proStatusProvider), ProStatus.pro);
    });

    test('vip token surfaces as vip status', () async {
      final c = makeContainer();
      await c
          .read(entitlementTokenProvider.notifier)
          .adopt(mint.mint(now: now, tier: 'vip'));
      expect(c.read(proStatusProvider), ProStatus.vip);
    });

    test('wrong public key means free (token unparseable)', () async {
      final c = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api),
        // Default (empty placeholder) key.
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      final ok = await c
          .read(entitlementTokenProvider.notifier)
          .adopt(mint.mint(now: now));
      expect(ok, isFalse);
      expect(c.read(proStatusProvider), ProStatus.free);
    });

    test('a stored token signed by a rotated key is refreshed, not dropped',
        () async {
      // A second mint = a different signing key: the stored raw fails local
      // verification but is still refreshable server-side.
      final rotated = EntitlementMint();
      final seed = makeContainer();
      await seed
          .read(settingsStoreProvider)
          .saveEntitlementToken(rotated.mint(now: now));
      api.nextToken = mint.mint(now: now);

      final c = makeContainer();
      c.read(entitlementTokenProvider);
      await settle(c, () => api.refreshCalls > 0);
      await settle(c, () => c.read(entitlementTokenProvider) != null);
      expect(c.read(entitlementTokenProvider), isNotNull);
      expect(c.read(proStatusProvider), ProStatus.pro);
      // The refresh was bound to this install's device id (no dev claim was
      // readable from the unverifiable raw).
      expect(api.lastDeviceId,
          await c.read(settingsStoreProvider).loadDeviceId());
      // The persisted token now verifies against the embedded key. adopt()
      // flips state before its save lands, so poll the file briefly.
      EntitlementToken? persisted;
      for (var i = 0; i < 100 && persisted == null; i++) {
        final raw =
            await c.read(settingsStoreProvider).loadEntitlementToken();
        persisted = raw == null
            ? null
            : EntitlementToken.tryParse(raw, publicKey: mint.publicKey);
        if (persisted == null) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }
      expect(persisted, isNotNull);
    });

    test('terminal 403 on an unverifiable token clears it', () async {
      final rotated = EntitlementMint();
      final seed = makeContainer();
      await seed
          .read(settingsStoreProvider)
          .saveEntitlementToken(rotated.mint(now: now));
      api.nextError = EntitlementApiException(403, 'invalid_token');

      final c = makeContainer();
      c.read(entitlementTokenProvider);
      await settle(c, () => api.refreshCalls > 0);
      var cleared = false;
      for (var i = 0; i < 100 && !cleared; i++) {
        cleared =
            await c.read(settingsStoreProvider).loadEntitlementToken() == null;
        if (!cleared) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }
      expect(cleared, isTrue);
      expect(c.read(entitlementTokenProvider), isNull);
      expect(c.read(proStatusProvider), ProStatus.free);
    });

    test('network failure keeps the unverifiable raw stored for retry',
        () async {
      final rotated = EntitlementMint();
      final raw = rotated.mint(now: now);
      final seed = makeContainer();
      await seed.read(settingsStoreProvider).saveEntitlementToken(raw);
      api.nextError = Exception('socket');

      final c = makeContainer();
      c.read(entitlementTokenProvider);
      await settle(c, () => api.refreshCalls > 0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(api.refreshCalls, 1);
      // The raw stays on disk for the daily-timer / next-launch retries.
      expect(await c.read(settingsStoreProvider).loadEntitlementToken(), raw);
    });
  });

  group('DioEntitlementApi.status', () {
    test('parses channel/tier/pro_until and activations incl. this_device',
        () async {
      final adapter = _CannedAdapter(200, '''
        {"channel":"beta","tier":"pro","pro_until":0,"activations":[
          {"device_class":"android","activated_at":1752700000,"this_device":true},
          {"device_class":"windows","activated_at":1752700100}
        ]}''');
      final s = await _cannedApi(adapter).status('jwt-raw');
      expect(adapter.last?.path, '/v1/entitlement/status');
      expect(adapter.last?.data, {'token': 'jwt-raw'});
      expect(s.channel, 'beta');
      expect(s.tier, 'pro');
      expect(s.proUntil, 0);
      expect(s.activations, hasLength(2));
      expect(s.activations[0].deviceClass, 'android');
      expect(s.activations[0].activatedAt,
          DateTime.fromMillisecondsSinceEpoch(1752700000 * 1000, isUtc: true));
      expect(s.activations[0].thisDevice, isTrue);
      expect(s.activations[1].deviceClass, 'windows');
      expect(s.activations[1].thisDevice, isFalse);
    });

    test('missing activations parses as empty, not a failure', () async {
      final adapter =
          _CannedAdapter(200, '{"channel":"afdian","tier":"pro","pro_until":1}');
      final s = await _cannedApi(adapter).status('jwt-raw');
      expect(s.activations, isEmpty);
      expect(s.proUntil, 1);
    });

    test('worker refusal surfaces its code', () async {
      final adapter = _CannedAdapter(403, '{"error":"revoked"}');
      await expectLater(
          _cannedApi(adapter).status('jwt-raw'),
          throwsA(isA<EntitlementApiException>()
              .having((e) => e.code, 'code', 'revoked')
              .having((e) => e.isTerminal, 'isTerminal', isTrue)));
    });
  });

  group('EntitlementApiException.activations', () {
    test('code_activation_limit body carries classes + timestamps', () async {
      final adapter = _CannedAdapter(403, '''
        {"error":"code_activation_limit","activations":[
          {"device_class":"android","activated_at":1752700000},
          {"device_class":"linux","activated_at":1752700200}
        ]}''');
      try {
        await _cannedApi(adapter).redeemBeta(
            code: 'AVA-BETA-x', deviceId: 'dev-1', deviceClass: 'android');
        fail('expected EntitlementApiException');
      } on EntitlementApiException catch (e) {
        expect(e.code, 'code_activation_limit');
        expect(e.activations, hasLength(2));
        expect(e.activations![0].deviceClass, 'android');
        expect(e.activations![1].deviceClass, 'linux');
        expect(
            e.activations![1].activatedAt,
            DateTime.fromMillisecondsSinceEpoch(1752700200 * 1000,
                isUtc: true));
        // Error payloads never identify devices.
        expect(e.activations!.any((a) => a.thisDevice), isFalse);
      }
    });

    test('errors without activations keep the field null; malformed entries '
        'are dropped, not fatal', () async {
      final bare = _CannedAdapter(403, '{"error":"code_invalid"}');
      try {
        await _cannedApi(bare).redeemBeta(
            code: 'nope', deviceId: 'dev-1', deviceClass: 'android');
        fail('expected EntitlementApiException');
      } on EntitlementApiException catch (e) {
        expect(e.code, 'code_invalid');
        expect(e.activations, isNull);
      }

      final mangled = _CannedAdapter(403,
          '{"error":"code_activation_limit","activations":[{"device_class":5}]}');
      try {
        await _cannedApi(mangled).redeemBeta(
            code: 'x', deviceId: 'dev-1', deviceClass: 'android');
        fail('expected EntitlementApiException');
      } on EntitlementApiException catch (e) {
        expect(e.activations, isEmpty);
      }
    });
  });

  group('deviceClassForPlatform', () {
    test('maps onto the worker vocabulary', () {
      expect(
          const {'android', 'windows', 'linux', 'macos'}
              .contains(deviceClassForPlatform()),
          isTrue);
      if (Platform.isLinux) {
        expect(deviceClassForPlatform(), 'linux');
      }
    });

    test('proActionsProvider sends the platform device class', () {
      expect(makeContainer().read(proActionsProvider).deviceClass,
          deviceClassForPlatform());
    });
  });

  group('proStatusProvider boundary timer', () {
    test('exp+grace passing while the app runs flips Pro off', () async {
      var clock = now; // mutable; the clockProvider closure reads it
      final c = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api),
        entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
        clockProvider.overrideWithValue(() => clock),
      ]);
      addTearDown(c.dispose);
      api.nextError = Exception('offline'); // refresh keeps failing
      await c.read(entitlementTokenProvider.notifier).adopt(
          mint.mint(now: now, pro: now.add(const Duration(days: 365))));
      expect(c.read(proStatusProvider), ProStatus.pro);
      fakeAsync((async) {
        c.invalidate(proStatusProvider); // schedule inside this zone
        final sub = c.listen(proStatusProvider, (_, _) {}); // keep it eager
        expect(c.read(proStatusProvider), ProStatus.pro);
        clock = now.add(const Duration(days: 9)); // past exp(24h)+grace(7d)
        async.elapse(const Duration(days: 9)); // boundary timers fire
        expect(c.read(proStatusProvider), ProStatus.free);
        sub.close();
      });
    });

    test('still pro inside the grace window', () async {
      var clock = now;
      final c = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api),
        entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
        clockProvider.overrideWithValue(() => clock),
      ]);
      addTearDown(c.dispose);
      api.nextError = Exception('offline');
      await c.read(entitlementTokenProvider.notifier).adopt(
          mint.mint(now: now, pro: now.add(const Duration(days: 365))));
      fakeAsync((async) {
        c.invalidate(proStatusProvider);
        final sub = c.listen(proStatusProvider, (_, _) {});
        clock = now.add(const Duration(days: 2)); // past exp, inside grace
        async.elapse(const Duration(days: 2));
        expect(c.read(proStatusProvider), ProStatus.pro);
        sub.close();
      });
    });

    test('lifetime token flips off after exp+grace; a refresh restores it',
        () async {
      var clock = now;
      final c = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api),
        entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
        clockProvider.overrideWithValue(() => clock),
      ]);
      addTearDown(c.dispose);
      api.nextError = Exception('offline');
      await c
          .read(entitlementTokenProvider.notifier)
          .adopt(mint.mint(now: now, lifetime: true));
      expect(c.read(proStatusProvider), ProStatus.pro);
      fakeAsync((async) {
        c.invalidate(proStatusProvider);
        final sub = c.listen(proStatusProvider, (_, _) {});
        clock = now.add(const Duration(days: 9));
        async.elapse(const Duration(days: 9));
        // Even lifetime needs a refresh past exp+grace (anti-tamper).
        expect(c.read(proStatusProvider), ProStatus.free);
        sub.close();
      });
      api.nextError = null;
      api.nextToken = mint.mint(now: clock, lifetime: true);
      await c.read(entitlementTokenProvider.notifier).refreshNow();
      expect(c.read(proStatusProvider), ProStatus.pro);
    });
  });
}
