import 'dart:convert';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount _account(int steamId, String name) => SteamGuardAccount(
      sharedSecret: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
      accountName: name,
      session: SessionData(steamId: steamId),
    );

/// Storage whose deleteFile always throws, to prove reset can't brick the
/// vault even when file cleanup fails.
class DeleteFailingStorage extends MemoryStorageProvider {
  @override
  Future<void> deleteFile(String filename) async {
    throw Exception('delete failed');
  }
}

void main() {
  test('performVaultReset leaves an unlocked empty store even if delete fails',
      () async {
    final storage = DeleteFailingStorage();
    // Seed a vault manifest + a payload, as if a real (now undecryptable)
    // vault were present.
    storage.files['manifest.json'] =
        jsonEncode(Manifest(vault: true, encrypted: true, entries: []).toJson());
    storage.files['111.maFile'] = 'opaque-vault-blob';

    final order = <String>[];
    await performVaultReset(
      storage: storage,
      clearKeys: () async => order.add('clearKeys'),
      disableBiometric: () async => order.add('disableBiometric'),
    );

    // The manifest was committed clean BEFORE the keys were dropped.
    final m = Manifest.fromJson(
        jsonDecode(storage.files['manifest.json']!) as Map<String, dynamic>);
    expect(m.vault, isFalse);
    expect(m.encrypted, isFalse);
    expect(m.entries, isEmpty);
    expect(order, ['clearKeys', 'disableBiometric']);

    // Bootstrap now yields an unlocked, empty store — never a locked vault.
    final reloaded = await AccountStore.load(storage);
    expect(reloaded.isVault, isFalse);
    expect(reloaded.encrypted, isFalse);
    expect(await reloaded.getAllAccounts(), isEmpty);
  });

  test('rebuildVaultManifest reconstitutes a vault store from payload files',
      () async {
    final storage = MemoryStorageProvider();
    final dek = VaultCrypto.generateDek();
    String blob(SteamGuardAccount a) =>
        VaultCrypto.encryptPayload(dek, jsonEncode(a.toJson()));
    // Migrated, vault-native, and code-only (negative synthetic id) payloads.
    storage.files['111.v2.maFile'] = blob(_account(111, 'alice'));
    storage.files['222.maFile'] = blob(_account(222, 'bob'));
    storage.files['-5.maFile'] = blob(_account(-5, 'code-only'));
    // A stale alt slot must lose to the .v2 file; junk names are skipped.
    storage.files['111.b.maFile'] = 'stale-legacy-blob';
    storage.files['junk.maFile'] = 'not-an-id';

    await AccountStore.rebuildVaultManifest(storage);

    final store = await AccountStore.load(storage);
    expect(store.isVault, isTrue);
    expect(store.encrypted, isTrue);
    expect(store.manifest.schemaVersion, 2);
    expect(store.entries.map((e) => e.steamId).toSet(), {111, 222, -5});
    expect(store.entries.firstWhere((e) => e.steamId == 111).filename,
        '111.v2.maFile');
    store.setDek(dek);
    expect((await store.getAllAccounts()).map((a) => a.accountName).toSet(),
        {'alice', 'bob', 'code-only'});
  });

  test('rebuildVaultManifest prefers the most recently written slot',
      () async {
    // Remove-then-relink can leave a stale `.v2` blob behind (slot deletes
    // are best-effort) with the live payload in the bare slot — the slot rank
    // alone would resurrect the stale one. Write order decides via
    // lastModified; MemoryStorageProvider's write sequence stands in for
    // mtimes.
    final storage = MemoryStorageProvider();
    final dek = VaultCrypto.generateDek();
    String blob(SteamGuardAccount a) =>
        VaultCrypto.encryptPayload(dek, jsonEncode(a.toJson()));
    await storage.writeFile('111.v2.maFile', blob(_account(111, 'stale')));
    await storage.writeFile('111.maFile', blob(_account(111, 'live')));

    await AccountStore.rebuildVaultManifest(storage);

    final store = await AccountStore.load(storage);
    expect(store.entries.single.filename, '111.maFile');
    store.setDek(dek);
    expect((await store.getAllAccounts()).single.accountName, 'live');
  });

  test('rebuildVaultManifest keeps the .v2 slot when it is the newest',
      () async {
    final storage = MemoryStorageProvider();
    final dek = VaultCrypto.generateDek();
    String blob(SteamGuardAccount a) =>
        VaultCrypto.encryptPayload(dek, jsonEncode(a.toJson()));
    await storage.writeFile('111.maFile', blob(_account(111, 'stale')));
    await storage.writeFile('111.v2.maFile', blob(_account(111, 'live')));

    await AccountStore.rebuildVaultManifest(storage);

    final store = await AccountStore.load(storage);
    expect(store.entries.single.filename, '111.v2.maFile');
    store.setDek(dek);
    expect((await store.getAllAccounts()).single.accountName, 'live');
  });

  test('rebuildVaultManifest equal-mtime tie prefers the bare slot', () async {
    // Coarse (1s) filesystem mtimes can land a remove-then-relink pair on
    // identical timestamps. The tie must go to the re-created canonical bare
    // name, not the leftover .v2 — write order here (bare first) would make
    // the mtime path pick .v2, so this pins the tie branch specifically.
    final storage = _FixedMtimeStorage();
    final dek = VaultCrypto.generateDek();
    String blob(SteamGuardAccount a) =>
        VaultCrypto.encryptPayload(dek, jsonEncode(a.toJson()));
    await storage.writeFile('111.maFile', blob(_account(111, 'live')));
    await storage.writeFile('111.v2.maFile', blob(_account(111, 'stale')));

    await AccountStore.rebuildVaultManifest(storage);

    final store = await AccountStore.load(storage);
    expect(store.entries.single.filename, '111.maFile');
    store.setDek(dek);
    expect((await store.getAllAccounts()).single.accountName, 'live');
  });
}

class _FixedMtimeStorage extends MemoryStorageProvider {
  @override
  Future<DateTime?> lastModified(String filename) async =>
      DateTime.fromMillisecondsSinceEpoch(1000);
}
