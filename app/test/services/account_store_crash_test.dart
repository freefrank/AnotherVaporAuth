import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount _account(int steamId, String name) => SteamGuardAccount(
      sharedSecret: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
      identitySecret: 'YWJjZGVmZ2hpamtsbW5vcHFyc3Q=',
      accountName: name,
      revocationCode: 'R12345',
      fullyEnrolled: true,
      session: SessionData(steamId: steamId, accessToken: 'tok'),
    );

/// In-memory storage that can be told to throw on the Nth write of a given
/// filename, to simulate a crash/partial write at a precise point.
class FailingStorageProvider extends MemoryStorageProvider {
  /// filename -> remaining successful writes before it throws (null = never).
  final Map<String, int> failAfter = {};

  @override
  Future<void> writeFile(String filename, String contents) async {
    final n = failAfter[filename];
    if (n != null) {
      if (n <= 0) throw const FileSystemFailure();
      failAfter[filename] = n - 1;
    }
    return super.writeFile(filename, contents);
  }
}

class FileSystemFailure implements Exception {
  const FileSystemFailure();
}

void main() {
  const pin = '123456';

  group('legacy encrypted update is crash-safe (finding #1)', () {
    test('a crash during the manifest write leaves the old account readable',
        () async {
      final storage = FailingStorageProvider();
      final store = AccountStore(storage);
      expect(await store.saveAccount(_account(111, 'alice'), false), isTrue);
      expect(await store.changeEncryptionKey(null, pin), isTrue);

      // Fail the manifest write during the *next* update, after the new
      // payload file has been written.
      storage.failAfter['manifest.json'] = 0;
      final updated = _account(111, 'alice-v2');
      expect(await store.saveAccount(updated, true, passKey: pin), isFalse);

      // The store on disk must still open with the original key and data.
      final reloaded = await AccountStore.load(storage);
      final accounts = await reloaded.getAllAccounts(passKey: pin);
      expect(accounts.length, 1);
      expect(accounts.single.accountName, anyOf('alice', 'alice-v2'));
      // Whichever it is, it decrypts — no salt/iv vs ciphertext mismatch.
    });
  });

  group('changeEncryptionKey is transactional (finding #2)', () {
    test('a crash mid-rotation leaves every account openable with the old key',
        () async {
      final storage = FailingStorageProvider();
      final store = AccountStore(storage);
      expect(await store.saveAccount(_account(111, 'alice'), false), isTrue);
      expect(await store.saveAccount(_account(222, 'bob'), false), isTrue);
      // Encrypt with the first key.
      expect(await store.changeEncryptionKey(null, pin), isTrue);

      // After the first encryption the files are already in the `.b` slot, so
      // this rotation writes back to the bare `<id>.maFile` slot. Fail bob's
      // new-payload write to simulate a crash mid-rotation.
      storage.failAfter['222.maFile'] = 0;
      const pin2 = '654321';
      // The rotation throws mid-way (uncaught) — simulate the crash.
      await expectLater(
          store.changeEncryptionKey(pin, pin2), throwsA(isA<FileSystemFailure>()));

      // Disk still holds the pre-rotation manifest + files: old key opens all.
      final reloaded = await AccountStore.load(storage);
      final accounts = await reloaded.getAllAccounts(passKey: pin);
      expect(accounts.map((a) => a.accountName).toSet(), {'alice', 'bob'});
      // The new key must NOT work (rotation never committed).
      expect(await reloaded.getAllAccounts(passKey: pin2), isEmpty);
    });

    test('a clean rotation re-keys all accounts and deletes old files',
        () async {
      final storage = FailingStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(111, 'alice'), false);
      await store.saveAccount(_account(222, 'bob'), false);
      expect(await store.changeEncryptionKey(null, pin), isTrue);
      expect(await store.changeEncryptionKey(pin, '654321'), isTrue);

      final reloaded = await AccountStore.load(storage);
      final accounts = await reloaded.getAllAccounts(passKey: '654321');
      expect(accounts.map((a) => a.accountName).toSet(), {'alice', 'bob'});
      expect(await reloaded.getAllAccounts(passKey: pin), isEmpty);
    });
  });

  group('one corrupt account does not blank the whole list (finding #6)', () {
    test('other accounts still load when one payload is corrupt', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(111, 'alice'), false);
      await store.saveAccount(_account(222, 'bob'), false);

      // Corrupt bob's payload on disk.
      storage.files['222.maFile'] = 'not valid json at all';

      final reloaded = await AccountStore.load(storage);
      final accounts = await reloaded.getAllAccounts();
      expect(accounts.map((a) => a.accountName), ['alice']);
    });

    test('wrong key on an encrypted store still returns empty', () async {
      final storage = MemoryStorageProvider();
      final store = AccountStore(storage);
      await store.saveAccount(_account(111, 'alice'), false);
      await store.changeEncryptionKey(null, pin);

      final reloaded = await AccountStore.load(storage);
      expect(await reloaded.getAllAccounts(passKey: '000000'), isEmpty);
      expect((await reloaded.getAllAccounts(passKey: pin)).length, 1);
    });
  });
}
