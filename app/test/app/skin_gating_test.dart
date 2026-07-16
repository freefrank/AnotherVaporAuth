import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/entitlement_mint.dart';

class _NoApi implements EntitlementApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<String>.error(Exception('offline'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mint = EntitlementMint();
  final now = DateTime.utc(2026, 7, 15, 12);

  late Directory tmp;
  late MemoryStorageProvider storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ava_skin_gate');
    storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
  });

  tearDown(() => tmp.delete(recursive: true));

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      storageProvider.overrideWithValue(storage),
      entitlementApiProvider.overrideWithValue(_NoApi()),
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

  test('default skin is the plain look since 0.90', () {
    expect(makeContainer().read(skinProvider), AvaSkin.none);
  });

  test('free user with a stored Pro skin renders plain, selection kept',
      () async {
    final seed = makeContainer();
    await seed.read(settingsStoreProvider).saveSkin('neon');

    final c = makeContainer();
    c.read(effectiveSkinProvider);
    await settle(c, () => c.read(skinProvider) == AvaSkin.neon);
    expect(c.read(skinProvider), AvaSkin.neon); // selection preserved
    expect(c.read(effectiveSkinProvider), AvaSkin.none); // but not rendered
  });

  test('pro user keeps the selected skin', () async {
    final seed = makeContainer();
    await seed.read(settingsStoreProvider).saveSkin('pixel');
    await seed
        .read(settingsStoreProvider)
        .saveEntitlementToken(mint.mint(now: now));

    final c = makeContainer();
    c.read(effectiveSkinProvider);
    await settle(
        c,
        () =>
            c.read(skinProvider) == AvaSkin.pixel &&
            c.read(entitlementTokenProvider) != null);
    expect(c.read(effectiveSkinProvider), AvaSkin.pixel);
  });

  test('migration notice shows once, dismiss persists', () async {
    final seed = makeContainer();
    await seed.read(settingsStoreProvider).saveSkin('neon');

    final c = makeContainer();
    c.read(skinPaywallNoticeProvider);
    await settle(c, () => c.read(skinPaywallNoticeProvider));
    expect(c.read(skinPaywallNoticeProvider), isTrue);

    await c.read(skinPaywallNoticeProvider.notifier).dismiss();
    expect(c.read(skinPaywallNoticeProvider), isFalse);

    final c2 = makeContainer();
    c2.read(skinPaywallNoticeProvider);
    await settle(c2, () => c2.read(skinProvider) == AvaSkin.neon);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c2.read(skinPaywallNoticeProvider), isFalse);
  });

  test('no notice when nothing was degraded', () async {
    final c = makeContainer();
    c.read(skinPaywallNoticeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(skinPaywallNoticeProvider), isFalse);
  });
}
