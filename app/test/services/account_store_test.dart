import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sda/src/core/models/session_data.dart';
import 'package:sda/src/core/models/steam_guard_account.dart';
import 'package:sda/src/services/account_store.dart';
import 'package:sda/src/services/storage_provider.dart';

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
