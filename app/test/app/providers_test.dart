import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/avatar_service.dart';
import 'package:ava/src/services/biometric_unlock.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/vault_key_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// A valid 20-byte Steam shared secret, base64 (what generateCode expects).
final _secret = base64.encode(Uint8List.fromList(List.generate(20, (i) => i)));

String _maFile({int? steamId, bool withTokens = false}) => jsonEncode({
      'shared_secret': _secret,
      'identity_secret': _secret,
      'revocation_code': 'R12345',
      'account_name': 'tester',
      'Session': {
        'SteamID': steamId ?? 76561198000000123,
        if (withTokens) 'AccessToken': 'access-token',
        if (withTokens) 'RefreshToken': 'refresh-token',
      },
    });

/// No-network avatar resolver: import/persist paths fire refreshAvatars
/// unawaited, and a real fetch would leak HTTP errors across tests.
class _NoAvatars implements AvatarService {
  @override
  Future<SteamProfile> fetchProfile(int steamId) async =>
      const SteamProfile();

  @override
  Future<EquippedItems> fetchEquippedItems(
          int steamId, String? accessToken) async =>
      const EquippedItems();
}

/// Scripted avatar resolver for the refreshAvatars parallelism test: inert
/// until [active] (imports fire refreshAvatars unawaited and must not
/// pre-fill personas), then resolves `p<steamId>` after a small real delay —
/// long enough for concurrent calls to overlap — and throws for [failFor].
class _ScriptedAvatars implements AvatarService {
  final int failFor;
  bool active = false;
  int _inFlight = 0;
  int maxInFlight = 0;
  _ScriptedAvatars({this.failFor = 0});

  @override
  Future<SteamProfile> fetchProfile(int steamId) async {
    if (!active) return const SteamProfile();
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _inFlight--;
    if (steamId == failFor) throw Exception('profile fetch down');
    return SteamProfile(personaName: 'p$steamId');
  }

  @override
  Future<EquippedItems> fetchEquippedItems(
          int steamId, String? accessToken) async =>
      const EquippedItems();
}

/// Inert until [onFirstFetch] is armed; then the first profile fetch runs the
/// hook (modelling a concurrent reload replacing the account list mid-flight)
/// before resolving a persona.
class _SwapOnceAvatars implements AvatarService {
  Future<void> Function()? onFirstFetch;

  @override
  Future<SteamProfile> fetchProfile(int steamId) async {
    final hook = onFirstFetch;
    if (hook == null) return const SteamProfile();
    onFirstFetch = null;
    await hook();
    return const SteamProfile(personaName: 'fresh-persona');
  }

  @override
  Future<EquippedItems> fetchEquippedItems(
          int steamId, String? accessToken) async =>
      const EquippedItems();
}

/// resetVault's key-drop path talks to platform keystores; off-device the
/// plugin channel is absent, so the controller test stubs it out.
class _NoopVaultKeys implements VaultKeyStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoopBiometric implements BiometricUnlock {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  group('AppController.importMaFile', () {
    late MemoryStorageProvider storage;
    late ProviderContainer container;

    setUp(() {
      storage = MemoryStorageProvider();
      container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        // Avoid a real network call from the post-accept bootstrap hook.
        timeAlignerProvider.overrideWithValue(() async {}),
        avatarServiceProvider.overrideWithValue(_NoAvatars()),
      ]);
      addTearDown(container.dispose);
    });

    test('returns the imported account, already reflected in state',
        () async {
      await container.read(appControllerProvider.future); // wait for bootstrap

      final account = await container
          .read(appControllerProvider.notifier)
          .importMaFile(_maFile(steamId: 76561198000000321));

      expect(account.steamId, 76561198000000321);
      expect(account.accountName, 'tester');
      final state = container.read(appControllerProvider).value!;
      expect(state.accounts.map((a) => a.steamId), contains(account.steamId));
    });

    test(
        'imported account with no session tokens reports hasTokens=false '
        '(the signal import_helper uses to decide whether to prompt)',
        () async {
      await container.read(appControllerProvider.future);

      final account = await container
          .read(appControllerProvider.notifier)
          .importMaFile(_maFile(withTokens: false));

      expect(account.session.hasTokens, isFalse);
    });

    test('findImportCollision returns null for a new id', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);

      expect(
          notifier.findImportCollision(_maFile(steamId: 76561198000000999)),
          isNull);
    });

    test(
        'findImportCollision returns the stored account after importing '
        'the same file', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      await notifier.importMaFile(_maFile(steamId: 76561198000000321));

      final dup =
          notifier.findImportCollision(_maFile(steamId: 76561198000000321));
      expect(dup, isNotNull);
      expect(dup!.storedReadable, isTrue);
      expect(dup.account.accountName, 'tester');
      expect(dup.account.steamId, 76561198000000321);
    });

    test(
        'findImportCollision reports storedReadable=false when only the '
        'manifest entry survives (payload undecodable)', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      await notifier.importMaFile(_maFile(steamId: 76561198000000321));

      // Corrupt the stored payload; after a reload the entry remains but no
      // decoded account backs it.
      storage.files['76561198000000321.maFile'] = 'not json';
      await notifier.reload();

      final dup =
          notifier.findImportCollision(_maFile(steamId: 76561198000000321));
      expect(dup, isNotNull);
      expect(dup!.storedReadable, isFalse);
      // The parsed incoming stands in, for display only.
      expect(dup.account.steamId, 76561198000000321);
    });

    test(
        'importMaFile over an existing account preserves session tokens '
        'when the new file has none', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      await notifier.importMaFile(
          _maFile(steamId: 76561198000000321, withTokens: true));

      final account = await notifier.importMaFile(
          _maFile(steamId: 76561198000000321, withTokens: false));

      // A stale backup must not kill a working login (mergeImportedAccount).
      expect(account.session.hasTokens, isTrue);
      final saved = jsonDecode(storage.files['76561198000000321.maFile']!)
          as Map<String, dynamic>;
      expect((saved['Session'] as Map<String, dynamic>)['RefreshToken'],
          'refresh-token');
    });

    test('persistSession writes the payload without reloading state',
        () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      final account = await notifier
          .importMaFile(_maFile(steamId: 76561198000000555, withTokens: true));
      final accountsBefore =
          container.read(appControllerProvider).value!.accounts;

      account.session.refreshToken = 'rotated';
      expect(await notifier.persistSession(account), isTrue);

      final saved = jsonDecode(storage.files['76561198000000555.maFile']!)
          as Map<String, dynamic>;
      expect(
          (saved['Session'] as Map<String, dynamic>)['RefreshToken'], 'rotated');
      // No reload / avatar refetch: the in-memory list is untouched.
      expect(
          identical(container.read(appControllerProvider).value!.accounts,
              accountsBefore),
          isTrue);
    });

    test(
        'persistSession from a stale instance keeps newer on-disk fields '
        'and writes only the session', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      // X: the instance a long-lived tab captured before later changes.
      final x = await notifier
          .importMaFile(_maFile(steamId: 76561198000000777, withTokens: true));

      // Y: the account changes on disk behind X's back (persistAccount
      // reloads state, so X is no longer the loaded instance).
      final y = SteamGuardAccount.fromJson(x.toJson());
      y.password = 'saved-password';
      expect(await notifier.persistAccount(y), isTrue);

      x.session.refreshToken = 'renewed-refresh';
      expect(await notifier.persistSession(x), isTrue);

      final saved = jsonDecode(storage.files['76561198000000777.maFile']!)
          as Map<String, dynamic>;
      // X's renewed session landed...
      expect((saved['Session'] as Map<String, dynamic>)['RefreshToken'],
          'renewed-refresh');
      // ...without X's stale snapshot clobbering Y's newer field.
      expect(saved['password'], 'saved-password');
    });

    test('persistSession refuses to resurrect a removed account', () async {
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      final x = await notifier
          .importMaFile(_maFile(steamId: 76561198000000888, withTokens: true));

      // The account is removed while the caller's session refresh is still
      // in flight; the queued save must not re-insert it. (Store-level
      // removal + reload: notifier.removeAccount also clears the keystore,
      // which has no platform channel in a plain test.)
      final data0 = container.read(appControllerProvider).value!;
      expect(await data0.store.removeAccount(x), isTrue);
      await notifier.reload();
      expect(storage.files.containsKey('76561198000000888.maFile'), isFalse);

      x.session.refreshToken = 'zombie';
      expect(await notifier.persistSession(x), isFalse);
      final data = container.read(appControllerProvider).value!;
      expect(
        data.store.entries.where((e) => e.steamId == 76561198000000888),
        isEmpty,
      );
      expect(storage.files.containsKey('76561198000000888.maFile'), isFalse);
    });
  });

  group('AppController.reorder', () {
    const a = 76561198000000101;
    const x = 76561198000000109; // becomes undecodable mid-list
    const b = 76561198000000102;
    const c = 76561198000000103;

    late MemoryStorageProvider storage;
    late ProviderContainer container;

    // Manifest [A, X, B, C] with X undecodable → UI shows [A, B, C]: the
    // exact geometry where index-based manifest moves address the wrong
    // (invisible) entry.
    setUp(() async {
      storage = MemoryStorageProvider();
      container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        timeAlignerProvider.overrideWithValue(() async {}),
        avatarServiceProvider.overrideWithValue(_NoAvatars()),
      ]);
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      for (final id in [a, x, b, c]) {
        await notifier.importMaFile(_maFile(steamId: id));
      }
      storage.files['$x.maFile'] = 'not json';
      await notifier.reload();
      expect(
          container
              .read(appControllerProvider)
              .value!
              .accounts
              .map((acc) => acc.steamId),
          [a, b, c]);
    });

    test('drag C→0 moves C in the manifest, not the invisible X', () async {
      final notifier = container.read(appControllerProvider.notifier);

      await notifier.reorder(2, 0);

      final data = container.read(appControllerProvider).value!;
      expect(data.accounts.map((acc) => acc.steamId), [c, a, b]);
      expect(data.store.entries.map((e) => e.steamId), [c, a, x, b]);

      // The order was persisted and X's entry survived.
      await notifier.reload();
      final reloaded = container.read(appControllerProvider).value!;
      expect(reloaded.accounts.map((acc) => acc.steamId), [c, a, b]);
      expect(reloaded.store.entries.map((e) => e.steamId), contains(x));
    });

    test('drag A→end (no entry after it) appends behind every entry',
        () async {
      final notifier = container.read(appControllerProvider.notifier);

      await notifier.reorder(0, 2);

      final data = container.read(appControllerProvider).value!;
      expect(data.accounts.map((acc) => acc.steamId), [b, c, a]);
      expect(data.store.entries.map((e) => e.steamId), [x, b, c, a]);

      await notifier.reload();
      expect(
          container
              .read(appControllerProvider)
              .value!
              .accounts
              .map((acc) => acc.steamId),
          [b, c, a]);
    });

    test(
        'REGRESSION: a dragged account whose steamId matches no manifest '
        'entry resyncs with disk instead of faking success', () async {
      final notifier = container.read(appControllerProvider.notifier);
      final data = container.read(appControllerProvider).value!;
      // Diverge C in memory: its manifest entry keeps c, but the live
      // instance now answers with an id no entry carries — the manifest
      // move has nothing to grab.
      data.accounts.last.session.steamId = 76561198000000999;

      await notifier.reorder(2, 0);

      // Nothing persisted → the published order must match disk again, not
      // the optimistic move (which would snap back on the next restart).
      final published = container.read(appControllerProvider).value!;
      expect(published.accounts.map((acc) => acc.steamId), [a, b, c]);
      final onDisk = await AccountStore.load(storage);
      expect(onDisk.entries.map((e) => e.steamId), [a, x, b, c]);
      // And the post-reload order equals the on-disk manifest order.
      await notifier.reload();
      expect(
          container
              .read(appControllerProvider)
              .value!
              .accounts
              .map((acc) => acc.steamId),
          [a, b, c]);
    });
  });

  group('AppController.refreshAvatars', () {
    const idA = 76561198000000101;
    const idB = 76561198000000102; // its profile fetch throws
    const idC = 76561198000000103;

    test('fetches per-account in parallel; one failure does not abort the rest',
        () async {
      final storage = MemoryStorageProvider();
      final avatars = _ScriptedAvatars(failFor: idB);
      final container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        timeAlignerProvider.overrideWithValue(() async {}),
        avatarServiceProvider.overrideWithValue(avatars),
      ]);
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      for (final id in [idA, idB, idC]) {
        await notifier.importMaFile(_maFile(steamId: id));
      }
      // Drain the imports' unawaited refreshAvatars before arming the fake.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      avatars.active = true;

      await notifier.refreshAvatars();

      expect(avatars.maxInFlight, 3,
          reason: 'accounts must refresh concurrently, not one at a time');
      final byId = {
        for (final a
            in container.read(appControllerProvider).value!.accounts)
          a.steamId: a,
      };
      // B's failure is contained to B — A and C still refreshed + persisted.
      expect(byId[idA]!.personaName, 'p$idA');
      expect(byId[idC]!.personaName, 'p$idC');
      expect(byId[idB]!.personaName, isNull);
      expect(storage.files['$idA.maFile'], contains('p$idA'));
      expect(storage.files['$idC.maFile'], contains('p$idC'));
    });

    test(
        'REGRESSION: refreshAvatars re-reads disk when a concurrent reload '
        'replaces the account list mid-refresh', () async {
      final storage = MemoryStorageProvider();
      final avatars = _SwapOnceAvatars();
      final container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        timeAlignerProvider.overrideWithValue(() async {}),
        avatarServiceProvider.overrideWithValue(avatars),
      ]);
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final notifier = container.read(appControllerProvider.notifier);
      await notifier.importMaFile(_maFile(steamId: idA));
      // Drain the import's unawaited refreshAvatars before arming the hook.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      avatars.onFirstFetch = notifier.reload;

      await notifier.refreshAvatars();

      // The persona was persisted onto the replaced (old) instance; the
      // published state must reflect disk, not the swapped-in pre-save
      // snapshot a fast republish would keep on screen.
      expect(storage.files['$idA.maFile'], contains('fresh-persona'));
      expect(
          container
              .read(appControllerProvider)
              .value!
              .accounts
              .single
              .personaName,
          'fresh-persona');
    });
  });

  group('PersistedSettingController', () {
    // SettingsStore writes app_settings.json next to the maFiles dir on the
    // real filesystem, so the fake storage points at a temp dir.
    late Directory tmp;
    late MemoryStorageProvider storage;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ava_persisted_settings');
      addTearDown(() => tmp.delete(recursive: true));
      storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
    });

    ProviderContainer containerWithStorage() {
      final container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    /// The load in build() is async — poll (bounded) until it lands.
    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 50 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    test('publishes the default until the stored value loads, then applies it',
        () async {
      File(p.join(tmp.path, 'app_settings.json')).writeAsStringSync(jsonEncode({
        'skin': 'neon',
        'brightness_mode': 'dark',
        'text_size': 'large',
        'locale': 'zh',
        'hold_confirm': false,
        'haptics': false,
      }));
      final container = containerWithStorage();

      // Synchronous first read: the defaults, not the (unloaded) file.
      expect(container.read(skinProvider), AvaSkin.none);
      expect(container.read(brightnessModeProvider), AvaBrightnessMode.system);
      expect(container.read(textSizeProvider), AvaTextSize.small);
      expect(container.read(localeProvider), isNull);
      expect(container.read(holdConfirmProvider), isTrue);
      expect(container.read(hapticsProvider), isTrue);

      await settle(() =>
          container.read(skinProvider) == AvaSkin.neon &&
          container.read(brightnessModeProvider) == AvaBrightnessMode.dark &&
          container.read(textSizeProvider) == AvaTextSize.large &&
          container.read(localeProvider) == const Locale('zh') &&
          container.read(holdConfirmProvider) == false &&
          container.read(hapticsProvider) == false);
      expect(container.read(skinProvider), AvaSkin.neon);
      expect(container.read(brightnessModeProvider), AvaBrightnessMode.dark);
      expect(container.read(textSizeProvider), AvaTextSize.large);
      expect(container.read(localeProvider), const Locale('zh'));
      expect(container.read(holdConfirmProvider), isFalse);
      expect(container.read(hapticsProvider), isFalse);
    });

    test('an unknown stored enum name keeps the default', () async {
      File(p.join(tmp.path, 'app_settings.json')).writeAsStringSync(
          jsonEncode({'brightness_mode': 'blurple'}));
      final container = containerWithStorage();

      container.read(brightnessModeProvider); // trigger the async load
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(brightnessModeProvider), AvaBrightnessMode.system);
    });

    test('set updates state and writes through to the store', () async {
      final container = containerWithStorage();
      // Let build()'s async load land first: a set racing the initial load
      // can be overwritten by it (pre-existing semantics, kept by the
      // generic controller — settings screens only offer set() well after
      // the load resolved).
      container.read(brightnessModeProvider);
      container.read(holdConfirmProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await container
          .read(brightnessModeProvider.notifier)
          .setMode(AvaBrightnessMode.light);
      await container.read(holdConfirmProvider.notifier).set(false);

      expect(container.read(brightnessModeProvider), AvaBrightnessMode.light);
      expect(container.read(holdConfirmProvider), isFalse);
      // A fresh store instance (own cache) proves the values hit disk.
      final store = SettingsStore(storage);
      expect(await store.loadBrightnessMode(), 'light');
      expect(await store.loadHoldConfirm(), isFalse);
    });
  });

  group('MoveInRescueController', () {
    test('set and clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(moveInRescueProvider), isNull);
      container
          .read(moveInRescueProvider.notifier)
          .set((code: 'R123', secret: 's3cret'));
      expect(container.read(moveInRescueProvider),
          (code: 'R123', secret: 's3cret'));
      container.read(moveInRescueProvider.notifier).clear();
      expect(container.read(moveInRescueProvider), isNull);
    });
  });

  group('AppController manifest recovery', () {
    test(
        'a dir with no manifest throws ManifestParseException; resetVault '
        'recovers to a clean, unlocked bootstrap', () async {
      final storage = MemoryStorageProvider();
      // Payload but no manifest.json: dirExists() is true, load() throws.
      storage.files['111.maFile'] = '{"account_name":"orphan"}';
      final container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
        timeAlignerProvider.overrideWithValue(() async {}),
        vaultKeyStoreProvider.overrideWithValue(_NoopVaultKeys()),
        biometricUnlockProvider.overrideWithValue(_NoopBiometric()),
      ]);
      addTearDown(container.dispose);

      // Bootstrap fails. Riverpod 3 auto-retries a failing build (so its
      // `.future` stays pending) — assert on the error state instead.
      var state = container.read(appControllerProvider);
      for (var i = 0; i < 100 && !state.hasError; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        state = container.read(appControllerProvider);
      }
      expect(state.error, isA<ManifestParseException>());

      await container.read(appControllerProvider.notifier).resetVault();

      final data = await container.read(appControllerProvider.future);
      expect(data.locked, isFalse);
      expect(data.encrypted, isFalse);
      expect(data.accounts, isEmpty);
      // The clean manifest was committed and the orphan payload dropped.
      expect(storage.files.containsKey('manifest.json'), isTrue);
      expect(storage.files.containsKey('111.maFile'), isFalse);
    });
  });
}
