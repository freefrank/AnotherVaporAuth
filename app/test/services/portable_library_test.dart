import 'dart:convert';
import 'dart:io';

import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/portable_library.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_dir.dart';

SteamGuardAccount account(int id, [String name = 'portable-user']) =>
    SteamGuardAccount.fromJson({
      'account_name': name,
      'shared_secret': 'c2hhcmVk',
      'identity_secret': 'aWRlbnRpdHk=',
      'revocation_code': 'R-PRIVATE',
      'Session': {'SteamID': id},
    });

class FailingStorage extends MemoryStorageProvider {
  bool failManifest = false;
  @override
  Future<void> writeFile(String name, String contents) async {
    if (name == 'manifest.json' && failManifest) {
      throw const FileSystemException('disk full');
    }
    await super.writeFile(name, contents);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'a long portable passphrase';

  test('outer Windows launcher directory wins over extraction path', () {
    expect(
      portableDirectory(
        operatingSystem: 'windows',
        executable: r'C:\Temp\nsis\ava.exe',
        environment: {'AVA_PORTABLE_ROOT': r'F:\工具\AVA'},
      ),
      r'F:\工具\AVA\maFiles',
    );
    expect(
      portableDirectory(
        operatingSystem: 'windows',
        executable: r'F:\AVA\ava.exe',
        environment: {},
      ),
      r'F:\AVA\maFiles',
    );
    expect(
      () => portableDirectory(
        operatingSystem: 'windows',
        executable: r'C:\ava.exe',
        environment: {'AVA_PORTABLE_ROOT': '..'},
      ),
      throwsFormatException,
    );
  });

  test(
    'AppImage and app bundle resolve outside the mounted/internal executable',
    () {
      expect(
        portableDirectory(
          operatingSystem: 'linux',
          executable: '/tmp/.mount/usr/bin/ava',
          environment: {'APPIMAGE': '/media/usb/AVA.AppImage'},
        ),
        '/media/usb/maFiles',
      );
      expect(
        portableDirectory(
          operatingSystem: 'macos',
          executable: '/Volumes/USB/AVA.app/Contents/MacOS/ava',
          environment: {},
        ),
        '/Volumes/USB/maFiles',
      );
      expect(
        portableDirectory(
          operatingSystem: 'android',
          executable: '/app',
          environment: {},
        ),
        isNull,
      );
    },
  );

  test(
    'discovery is read-only and reads plaintext maFiles without manifest',
    () async {
      final storage = MemoryStorageProvider();
      final lib = PortableLibrary(storage);
      await lib.discover();
      expect(storage.files, isEmpty);
      storage.files['one.MAFILE'] = jsonEncode(
        account(76561198000000001).toJson(),
      );
      await lib.discover();
      expect(lib.accounts.single.accountName, 'portable-user');
      expect(lib.accounts.single.fromPortable, isTrue);
      expect(storage.files.keys, ['one.MAFILE']);
    },
  );

  test(
    'copied folder unlocks without original OS credentials and rejects wrong password',
    () async {
      final sourceDir = await Directory.systemTemp.createTemp(
        'ava-portable-source-',
      );
      final newHostDir = await Directory.systemTemp.createTemp(
        'ava-portable-other-host-',
      );
      addTearDown(() => deleteTempDirSync(sourceDir));
      addTearDown(() => deleteTempDirSync(newHostDir));
      final source = PortableLibrary(DirectoryStorageProvider(sourceDir.path));
      await source.discover();
      await source.configure(password);
      await source.save(account(76561198000000001));
      await source.setEnabled(true);
      source.lock();
      // Transfer only maFiles, never platform secure storage or original objects.
      for (final file in sourceDir.listSync().whereType<File>()) {
        await file.copy('${newHostDir.path}/${file.uri.pathSegments.last}');
      }
      final newHost = PortableLibrary(
        DirectoryStorageProvider(newHostDir.path),
      );
      await newHost.discover();
      expect(newHost.enabled, isTrue);
      expect(newHost.locked, isTrue);
      expect(newHost.accounts, isEmpty);
      expect(await newHost.unlock('incorrect password'), isFalse);
      expect(await newHost.unlock(password), isTrue);
      expect(newHost.accounts.single.revocationCode, 'R-PRIVATE');
      expect(newHost.accounts.single.fromPortable, isTrue);
      for (final file in newHostDir.listSync().whereType<File>()) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains(password)));
        expect(text, isNot(contains('R-PRIVATE')));
      }
    },
  );

  test(
    'failed manifest update retains the old account across restart',
    () async {
      final storage = FailingStorage();
      final lib = PortableLibrary(storage);
      await lib.discover();
      await lib.configure(password);
      await lib.save(account(76561198000000001, 'before'));
      final manifest = storage.files['manifest.json'];
      storage.failManifest = true;
      await expectLater(
        lib.save(account(76561198000000001, 'after')),
        throwsA(isA<FileSystemException>()),
      );
      expect(storage.files['manifest.json'], manifest);
      expect(lib.accounts.single.accountName, 'before');
      storage.failManifest = false;
      final reopened = PortableLibrary(storage);
      await reopened.discover();
      expect(await reopened.unlock(password), isTrue);
      expect(reopened.accounts.single.accountName, 'before');
    },
  );

  test(
    'removed media or externally changed manifest never creates a replacement vault',
    () async {
      final storage = MemoryStorageProvider();
      final lib = PortableLibrary(storage);
      await lib.discover();
      await lib.configure(password);
      storage.files.clear();
      await expectLater(
        lib.save(account(76561198000000001)),
        throwsA(isA<FileSystemException>()),
      );
      expect(storage.files, isEmpty);
    },
  );

  test(
    'plaintext conversion survives restart; unsupported host-bound key stays untouched',
    () async {
      final storage = MemoryStorageProvider();
      storage.files['old.maFile'] = jsonEncode(
        account(76561198000000001).toJson(),
      );
      final lib = PortableLibrary(storage);
      await lib.discover();
      await lib.configure(password);
      expect(storage.files.containsKey('old.maFile'), isFalse);
      lib.lock();
      final reopened = PortableLibrary(storage);
      await reopened.discover();
      expect(await reopened.unlock(password), isTrue);
      expect(reopened.accounts.single.sharedSecret, 'c2hhcmVk');
      final manifest =
          jsonDecode(storage.files['manifest.json']!) as Map<String, dynamic>;
      manifest.remove('portable_key');
      storage.files['manifest.json'] = jsonEncode(manifest);
      final before = Map<String, String>.of(storage.files);
      final foreign = PortableLibrary(storage);
      await foreign.discover();
      expect(foreign.foreignVault, isTrue);
      expect(await foreign.unlock(password), isFalse);
      expect(storage.files, before);
    },
  );

  test(
    'failed plaintext conversion leaves the original library readable',
    () async {
      final storage = FailingStorage();
      storage.files['original.maFile'] = jsonEncode(
        account(76561198000000001).toJson(),
      );
      final original = storage.files['original.maFile'];
      final lib = PortableLibrary(storage);
      await lib.discover();
      storage.failManifest = true;
      await expectLater(
        lib.configure(password),
        throwsA(isA<FileSystemException>()),
      );
      expect(storage.files['original.maFile'], original);
      storage.failManifest = false;
      final reopened = PortableLibrary(storage);
      await reopened.discover();
      expect(reopened.error, isNull);
      expect(reopened.accounts.single.revocationCode, 'R-PRIVATE');
    },
  );

  test('malformed portable key cost is rejected before derivation', () async {
    final storage = MemoryStorageProvider();
    storage.files['manifest.json'] = jsonEncode({
      'vault': true,
      'encrypted': true,
      'entries': [],
      'portable_key': {'v': 1, 'iterations': 999999999999},
    });
    final lib = PortableLibrary(storage);
    await lib.discover();
    await expectLater(lib.unlock(password), throwsFormatException);
  });
}
