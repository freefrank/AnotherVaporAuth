import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/entitlement_mint.dart';

class _FakeApi implements EntitlementApi {
  String? nextToken;
  Object? nextError;
  int refreshCalls = 0;

  Future<String> _reply() async {
    if (nextError != null) throw nextError!;
    return nextToken!;
  }

  @override
  Future<String> refresh(String token, String deviceId) {
    refreshCalls++;
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
}

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

  tearDown(() => tmp.delete(recursive: true));

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
  });
}
