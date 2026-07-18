import 'dart:convert';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/services/avatar_service.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/credential_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _steamId = 76561198000000111;

/// A structurally valid JWT with a far-future exp, so accessTokenStale is
/// false and refreshSessions never touches the network (AutoLogin unused).
String _freshJwt() {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'EdDSA'})}.${b64({'exp': exp})}.sig';
}

SteamGuardAccount _account() => SteamGuardAccount(
      sharedSecret: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
      identitySecret: 'YWJjZGVmZ2hpamtsbW5vcHFyc3Q=',
      accountName: 'legacy-user',
      revocationCode: 'R12345',
      fullyEnrolled: true,
      session: SessionData(steamId: _steamId, accessToken: _freshJwt()),
    );

/// No-network avatar resolver: persistAccount fires refreshAvatars unawaited,
/// and a real fetch would leak HTTP errors across tests.
class _NoAvatars implements AvatarService {
  @override
  Future<SteamProfile> fetchProfile(int steamId) async =>
      const SteamProfile();

  @override
  Future<EquippedItems> fetchEquippedItems(
          int steamId, String? accessToken) async =>
      const EquippedItems();
}

/// In-memory stand-in for the legacy keystore password store.
class _FakeCreds implements CredentialStore {
  final Map<int, String> passwords;
  int clears = 0;
  _FakeCreds(this.passwords);

  @override
  Future<void> savePassword(int steamId, String password) async =>
      passwords[steamId] = password;

  @override
  Future<String?> password(int steamId) async => passwords[steamId];

  @override
  Future<void> clear(int steamId) async {
    clears++;
    passwords.remove(steamId);
  }
}

/// Runs [onFirstRead] once before answering the first password lookup —
/// the seam where refreshSessions awaits, so a hooked reload() models a
/// concurrent flow replacing the account list mid-refresh.
class _ReloadTriggeringCreds extends _FakeCreds {
  Future<void> Function()? onFirstRead;
  _ReloadTriggeringCreds(super.passwords);

  @override
  Future<String?> password(int steamId) async {
    final hook = onFirstRead;
    onFirstRead = null;
    if (hook != null) await hook();
    return super.password(steamId);
  }
}

/// Storage whose writes can be made to fail after seeding, to prove the
/// keystore copy is only dropped once the maFile actually holds the password.
class _FailingWritesStorage extends MemoryStorageProvider {
  bool failWrites = false;

  @override
  Future<void> writeFile(String filename, String contents) {
    if (failWrites) throw Exception('disk full');
    return super.writeFile(filename, contents);
  }
}

/// Counts payload reads, to pin that refreshSessions republishes the
/// in-memory accounts instead of re-reading (and re-decrypting) the store.
class _CountingReadsStorage extends MemoryStorageProvider {
  int reads = 0;

  @override
  Future<String> readFile(String filename) {
    reads++;
    return super.readFile(filename);
  }
}

void main() {
  Future<ProviderContainer> bootstrap(
      MemoryStorageProvider storage, _FakeCreds creds) async {
    // Seed via a real AccountStore so manifest + payload match production.
    await AccountStore(storage).saveAccount(_account(), false);
    final container = ProviderContainer(overrides: [
      storageProvider.overrideWithValue(storage),
      credentialStoreProvider.overrideWithValue(creds),
      timeAlignerProvider.overrideWithValue(() async {}),
      avatarServiceProvider.overrideWithValue(_NoAvatars()),
    ]);
    addTearDown(container.dispose);
    // Privacy not accepted in settings → build() skips the auto refresh
    // microtasks; refreshSessions is driven explicitly below.
    await container.read(appControllerProvider.future);
    return container;
  }

  test('legacy keystore password migrates into the maFile and is cleared',
      () async {
    final storage = MemoryStorageProvider();
    final creds = _FakeCreds({_steamId: 'legacy-pw'});
    final container = await bootstrap(storage, creds);

    await container.read(appControllerProvider.notifier).refreshSessions();

    final saved = jsonDecode(storage.files['$_steamId.maFile']!)
        as Map<String, dynamic>;
    expect(saved['password'], 'legacy-pw');
    expect(creds.passwords, isEmpty);
    expect(creds.clears, 1);
  });

  test(
      'REGRESSION: a deleted password stays deleted across refreshSessions '
      '(the keystore copy must not resurrect it)', () async {
    final storage = MemoryStorageProvider();
    final creds = _FakeCreds({_steamId: 'legacy-pw'});
    final container = await bootstrap(storage, creds);
    final notifier = container.read(appControllerProvider.notifier);

    await notifier.refreshSessions(); // migrates + clears the keystore copy

    // User re-logs-in with "save password" unchecked → password removed.
    final acc =
        container.read(appControllerProvider).value!.accounts.single;
    acc.password = null;
    await notifier.persistAccount(acc);

    await notifier.refreshSessions(); // next app open / unlock

    final saved = jsonDecode(storage.files['$_steamId.maFile']!)
        as Map<String, dynamic>;
    expect(saved['password'], isNull);
  });

  test(
      'refreshSessions republishes the live in-memory accounts with zero '
      'post-save re-reads (no full disk re-read + re-decrypt)', () async {
    final storage = _CountingReadsStorage();
    final creds = _FakeCreds({_steamId: 'legacy-pw'});
    final container = await bootstrap(storage, creds);
    final notifier = container.read(appControllerProvider.notifier);
    final before = container.read(appControllerProvider).value!.accounts;
    storage.reads = 0;

    // The password migration marks the account changed → the republish
    // branch runs. saveAccount writes; nothing may read.
    await notifier.refreshSessions();

    expect(storage.reads, 0,
        reason: 'the republish must reuse the mutated in-memory instances, '
            'not re-read every payload from disk');
    final after = container.read(appControllerProvider).value!.accounts;
    // New list identity (so Riverpod notifies) around the same live objects.
    expect(identical(after, before), isFalse);
    expect(identical(after.single, before.single), isTrue);
    // And the published instance carries the refreshed state.
    expect(after.single.password, 'legacy-pw');
  });

  test(
      'REGRESSION: when a concurrent reload replaces the account list '
      'mid-refresh, refreshSessions re-reads disk instead of republishing '
      'the replaced (pre-save) instances', () async {
    final storage = MemoryStorageProvider();
    final creds = _ReloadTriggeringCreds({_steamId: 'legacy-pw'});
    final container = await bootstrap(storage, creds);
    final notifier = container.read(appControllerProvider.notifier);
    // Mid-refresh — before the migration mutates + saves the old instance —
    // a concurrent reload swaps in fresh instances read from disk.
    creds.onFirstRead = notifier.reload;

    await notifier.refreshSessions();

    // The migration landed on disk via the old (replaced) instance…
    final saved = jsonDecode(storage.files['$_steamId.maFile']!)
        as Map<String, dynamic>;
    expect(saved['password'], 'legacy-pw');
    // …so the published state must match disk: a fast republish of the
    // replaced list would keep the pre-migration snapshot (no password,
    // stale tokens) on screen for the rest of the session.
    final published =
        container.read(appControllerProvider).value!.accounts.single;
    expect(published.password, 'legacy-pw');
  });

  test('a failed maFile save keeps the keystore copy for the next attempt',
      () async {
    final storage = _FailingWritesStorage();
    final creds = _FakeCreds({_steamId: 'legacy-pw'});
    final container = await bootstrap(storage, creds);

    storage.failWrites = true;
    await container.read(appControllerProvider.notifier).refreshSessions();

    expect(creds.passwords[_steamId], 'legacy-pw');
    expect(creds.clears, 0);
  });
}
