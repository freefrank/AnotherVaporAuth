import 'dart:convert';
import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/portable_library.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../support/temp_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'portable testing password';
  late Directory temp;
  late ProviderContainer container;
  late PortableLibrary portable;
  late MemoryStorageProvider local;
  late MemoryStorageProvider usb;
  late AppController controller;
  String payload(int id, String name) => jsonEncode({
    'account_name': name,
    'shared_secret': 'c2hhcmVk',
    'identity_secret': 'aWRlbnRpdHk=',
    'Session': {'SteamID': id},
  });
  const first = 76561198000000001;
  const second = 76561198000000002;
  const third = 76561198000000003;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('ava-portable-controller-');
    local = MemoryStorageProvider('${temp.path}/local/maFiles');
    usb = MemoryStorageProvider('${temp.path}/usb/maFiles');
    portable = PortableLibrary(usb);
    container = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(local),
        portableLibraryProvider.overrideWithValue(portable),
        timeAlignerProvider.overrideWithValue(() async {}),
      ],
    );
    await container.read(appControllerProvider.future);
    controller = container.read(appControllerProvider.notifier);
    await portable.configure(password);
  });
  tearDown(() {
    container.dispose();
    deleteTempDirSync(temp);
  });

  test(
    'switch offers source-preserving copies, duplicate priority and correct write destination',
    () async {
      await controller.importMaFile(payload(first, 'local'));
      await portable.save(
        SteamGuardAccount.fromJson(jsonDecode(payload(first, 'usb'))),
      );
      await portable.save(
        SteamGuardAccount.fromJson(jsonDecode(payload(second, 'usb-only'))),
      );
      expect(await controller.setPortableMode(true, migrate: true), 1);
      var data = container.read(appControllerProvider).value!;
      expect(data.accounts.single.accountName, 'local');
      expect(data.visibleAccounts.map((a) => a.accountName), [
        'usb',
        'usb-only',
      ]);
      await controller.importMaFile(payload(third, 'new-usb'));
      expect(
        local.files.keys.where((name) => name.startsWith('$third.')),
        isEmpty,
      );
      expect(portable.ids, contains(third));
      expect(await controller.setPortableMode(false, migrate: true), 1);
      data = container.read(appControllerProvider).value!;
      expect(data.accounts.map((a) => a.accountName), [
        'local',
        'usb-only',
        'new-usb',
      ]);
      expect(data.visibleAccounts.first.accountName, 'local');
      expect(portable.accounts.first.accountName, 'usb');
      expect(portable.ids, containsAll([first, second, third]));
    },
  );

  test(
    'switch-only leaves the source in place; portable edit/delete never touches local duplicate',
    () async {
      await controller.importMaFile(payload(first, 'local'));
      await portable.save(
        SteamGuardAccount.fromJson(jsonDecode(payload(first, 'usb'))),
      );
      final localBytes = local.files['$first.maFile'];
      await controller.setPortableMode(true, migrate: false);
      final selected = container
          .read(appControllerProvider)
          .value!
          .visibleAccounts
          .single;
      selected.personaName = 'portable edit';
      expect(await controller.persistAccount(selected), isTrue);
      expect(local.files['$first.maFile'], localBytes);
      expect(portable.accounts.single.personaName, 'portable edit');
      await controller.removeAccount(selected);
      expect(portable.ids, isEmpty);
      expect(local.files['$first.maFile'], localBytes);
      expect(
        container
            .read(appControllerProvider)
            .value!
            .visibleAccounts
            .single
            .accountName,
        'local',
      );
      await controller.setPortableMode(false, migrate: false);
      expect(portable.enabled, isFalse);
    },
  );

  test(
    'local-only sync writes cannot be redirected to USB by the mode switch',
    () async {
      await controller.setPortableMode(true, migrate: false);
      await controller.importMaFile(
        payload(first, 'sync-local'),
        localOnly: true,
      );
      expect(portable.ids, isEmpty);
      expect(
        container
            .read(appControllerProvider)
            .value!
            .accounts
            .single
            .accountName,
        'sync-local',
      );
      await controller.importMaFile(payload(second, 'usb'));
      // This is the same local snapshot AppAccountsPort exposes to WebDAV.
      expect(container.read(appControllerProvider).value!.accounts.length, 1);
      expect(
        container.read(appControllerProvider).value!.visibleAccounts.length,
        2,
      );
      await controller.removeAccountBySteamId(first, localOnly: true);
      expect(portable.ids, [second]);
    },
  );

  test(
    'locked enabled destination never silently imports into AppData',
    () async {
      await controller.setPortableMode(true, migrate: false);
      portable.lock();
      await expectLater(
        controller.importMaFile(payload(first, 'blocked')),
        throwsStateError,
      );
      expect(container.read(appControllerProvider).value!.accounts, isEmpty);
      expect(portable.ids, isEmpty);
    },
  );
}
