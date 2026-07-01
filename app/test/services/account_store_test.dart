import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/storage_provider.dart';

SteamGuardAccount _account(int steamId, String name) => SteamGuardAccount(
      sharedSecret: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
      identitySecret: 'YWJjZGVmZ2hpamtsbW5vcHFyc3Q=',
      accountName: name,
      revocationCode: 'R12345',
      fullyEnrolled: true,
      session: SessionData(steamId: steamId, accessToken: 'tok'),
    );

void main() {
  group('AccountStore unencrypted', () {
    test('save and reload account', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);

      expect(await store.saveAccount(_account(111, 'alice'), false), isTrue);
      expect(storage.files.containsKey('111.maFile'), isTrue);
      expect(storage.files.containsKey('manifest.json'), isTrue);

      final reloaded = await AccountStore.load(storage);
      expect(reloaded.entries.length, 1);
      final accounts = await reloaded.getAllAccounts();
      expect(accounts.single.accountName, 'alice');
      expect(accounts.single.steamId, 111);
    });

    test('maFile is plain JSON when unencrypted', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(222, 'bob'), false);
      final decoded = jsonDecode(storage.files['222.maFile']!);
      expect(decoded['account_name'], 'bob');
    });
  });

  group('AccountStore encryption', () {
    test('PIN can be set on an empty store and survives reload', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);

      // Set a PIN with zero accounts.
      expect(await store.changeEncryptionKey(null, '123456'), isTrue);
      expect(store.encrypted, isTrue);
      expect(await store.verifyPasskey('123456'), isTrue);
      expect(await store.verifyPasskey('000000'), isFalse);

      // Reloading must NOT silently drop encryption just because it's empty.
      final reloaded = await AccountStore.load(storage);
      expect(reloaded.encrypted, isTrue);
      expect(await reloaded.verifyPasskey('123456'), isTrue);
      expect(await reloaded.verifyPasskey('999999'), isFalse);
    });

    test('encrypt, verify passkey, decrypt back', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      const key = 's3cret-passkey';

      expect(await store.saveAccount(_account(333, 'carol'), true, passKey: key),
          isTrue);
      expect(store.encrypted, isTrue);
      // Stored file must not be plain JSON.
      expect(storage.files['333.maFile'], isNot(contains('account_name')));

      expect(await store.verifyPasskey(key), isTrue);
      expect(await store.verifyPasskey('wrong'), isFalse);

      final accounts = await store.getAllAccounts(passKey: key);
      expect(accounts.single.accountName, 'carol');
      // Wrong key yields empty list (not a throw).
      expect(await store.getAllAccounts(passKey: 'wrong'), isEmpty);
    });

    test('changeEncryptionKey re-encrypts then decrypts to clear', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(444, 'dave'), false);

      // Encrypt from clear.
      expect(await store.changeEncryptionKey(null, 'k1'), isTrue);
      expect(store.encrypted, isTrue);
      expect(await store.verifyPasskey('k1'), isTrue);

      // Rotate key.
      expect(await store.changeEncryptionKey('k1', 'k2'), isTrue);
      expect(await store.verifyPasskey('k2'), isTrue);
      expect(await store.verifyPasskey('k1'), isFalse);

      // Decrypt back to clear.
      expect(await store.changeEncryptionKey('k2', null), isTrue);
      expect(store.encrypted, isFalse);
      final accounts = await store.getAllAccounts();
      expect(accounts.single.accountName, 'dave');
    });
  });

  group('AccountStore vault (DEK / AES-GCM) mode', () {
    Future<(AccountStore, MemoryStorageProvider, List<SteamGuardAccount>)>
        legacyStoreWithTwo() async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.changeEncryptionKey(null, '123456');
      await store.saveAccount(_account(111, 'alice'), true, passKey: '123456');
      await store.saveAccount(_account(222, 'bob'), true, passKey: '123456');
      final accounts = await store.getAllAccounts(passKey: '123456');
      expect(accounts.length, 2);
      return (store, storage, accounts);
    }

    test('migrates a legacy encrypted store to the vault scheme', () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();

      await store.migrateToVault(dek, accounts);

      expect(store.isVault, isTrue);
      expect(store.manifest.schemaVersion, 2);
      expect(store.manifest.passkeyCheck, isNull);
      // Old CBC files removed; v2 vault files written.
      expect(storage.files.containsKey('111.maFile'), isFalse);
      expect(storage.files.containsKey('111.v2.maFile'), isTrue);
      // The vault file is neither plain JSON nor legacy CBC text.
      expect(() => jsonDecode(storage.files['111.v2.maFile']!),
          throwsFormatException);
      expect(storage.files['111.v2.maFile'], isNot(contains('account_name')));

      // Reload from disk, provide the DEK, read the accounts back.
      final reloaded = await AccountStore.load(storage);
      expect(reloaded.isVault, isTrue);
      reloaded.setDek(dek);
      final back = await reloaded.getAllAccounts();
      expect(back.map((a) => a.accountName).toSet(), {'alice', 'bob'});
    });

    test('vault reads need the right DEK', () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();
      await store.migrateToVault(dek, accounts);

      final reloaded = await AccountStore.load(storage);
      // No DEK provided yet.
      expect(await reloaded.getAllAccounts(), isEmpty);
      // Wrong DEK.
      reloaded.setDek(VaultCrypto.generateDek());
      expect(await reloaded.getAllAccounts(), isEmpty);
      // Correct DEK.
      reloaded.setDek(dek);
      expect((await reloaded.getAllAccounts()).length, 2);
    });

    test('saveAccount in vault mode encrypts new accounts under the DEK',
        () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();
      await store.migrateToVault(dek, accounts);

      expect(await store.saveAccount(_account(333, 'carol'), true), isTrue);
      final reloaded = await AccountStore.load(storage);
      reloaded.setDek(dek);
      final back = await reloaded.getAllAccounts();
      expect(back.map((a) => a.accountName).toSet(), {'alice', 'bob', 'carol'});
      // New account stored encrypted, not plain JSON.
      expect(storage.files['333.maFile'], isNot(contains('account_name')));
    });

    test('saveAccount fails in vault mode without a DEK', () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();
      await store.migrateToVault(dek, accounts);
      store.setDek(null);
      expect(await store.saveAccount(_account(444, 'dave'), true), isFalse);
    });

    test('empty vault store stays encrypted across reload (PIN gate kept)',
        () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      final dek = VaultCrypto.generateDek();
      // Establish a vault with zero accounts (fresh install, PIN set, no accounts).
      await store.migrateToVault(dek, const []);
      expect(store.isVault, isTrue);
      expect(store.encrypted, isTrue);

      final reloaded = await AccountStore.load(storage);
      expect(reloaded.isVault, isTrue);
      expect(reloaded.encrypted, isTrue); // not silently downgraded
    });

    test('removing the last account keeps a vault store encrypted', () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();
      await store.migrateToVault(dek, accounts);
      for (final a in accounts) {
        await store.removeAccount(a);
      }
      expect(store.entries, isEmpty);
      expect(store.isVault, isTrue);
      expect(store.encrypted, isTrue);
    });

    test('migrateToVault is a no-op on an already-vault store', () async {
      final (store, storage, accounts) = await legacyStoreWithTwo();
      final dek = VaultCrypto.generateDek();
      await store.migrateToVault(dek, accounts);
      final filesAfterFirst = Map.of(storage.files);

      await store.migrateToVault(VaultCrypto.generateDek(), accounts);
      // Nothing re-encrypted with a different key.
      expect(storage.files.keys.toSet(), filesAfterFirst.keys.toSet());
      store.setDek(dek);
      expect((await store.getAllAccounts()).length, 2);
    });
  });

  group('AccountStore import / remove / reorder', () {
    test('import a maFile (clear store)', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      final contents = jsonEncode(_account(555, 'erin').toJson());

      final acc = await store.importMaFileContents(contents, null);
      expect(acc.steamId, 555);
      expect(store.entries.length, 1);
    });

    test('remove account deletes maFile and resets encryption', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      final acc = _account(666, 'frank');
      await store.saveAccount(acc, true, passKey: 'k');
      expect(store.encrypted, isTrue);

      expect(await store.removeAccount(acc), isTrue);
      expect(store.entries, isEmpty);
      expect(store.encrypted, isFalse);
      expect(storage.files.containsKey('666.maFile'), isFalse);
    });

    test('moveEntry reorders', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(1, 'a'), false);
      await store.saveAccount(_account(2, 'b'), false);
      await store.saveAccount(_account(3, 'c'), false);

      store.moveEntry(2, 0);
      expect(store.entries.map((e) => e.steamId).toList(), [3, 1, 2]);
    });
  });
}
