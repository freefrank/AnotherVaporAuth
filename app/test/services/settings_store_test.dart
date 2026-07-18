import 'dart:io';

import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// SettingsStore 直接写真实文件（app_settings.json 在 maFiles 旁边），
/// 用临时目录替身而非 MemoryStorageProvider。
class _TmpStorage extends StorageProvider {
  final String dir;
  _TmpStorage(this.dir);
  @override
  Future<String> maFilesDir() async => p.join(dir, 'maFiles');
}

void main() {
  test('hold-confirm and haptics default to true and persist', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadHoldConfirm(), isTrue);
      expect(await store.loadHaptics(), isTrue);
      await store.saveHoldConfirm(false);
      await store.saveHaptics(false);
      expect(await store.loadHoldConfirm(), isFalse);
      expect(await store.loadHaptics(), isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('concurrent saves of different keys do not lose updates', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      await Future.wait(
          [store.saveHoldConfirm(false), store.saveHaptics(false)]);
      expect(await store.loadHoldConfirm(), isFalse);
      expect(await store.loadHaptics(), isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('a burst of saves leaves no temp residue and round-trips every key',
      () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      await store.saveLocale('zh');
      await store.saveEntitlementToken('jwt-raw');
      await store.saveDeviceId('device-abc');

      // Atomic replace must never leave a *.tmp sibling behind — a leftover
      // could masquerade as data (or signal a torn write path).
      final names = Directory(tmp.path)
          .listSync()
          .map((e) => p.basename(e.path))
          .toList();
      expect(names, ['app_settings.json']);

      expect(await store.loadLocale(), 'zh');
      expect(await store.loadEntitlementToken(), 'jwt-raw');
      expect(await store.loadDeviceId(), 'device-abc');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('the entitlement token survives an unrelated save', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      await store.saveEntitlementToken('t');
      await store.saveHaptics(false);
      expect(await store.loadEntitlementToken(), 't');
      expect(await store.loadHaptics(), isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('a corrupt file loads as empty and the next save recovers it',
      () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      File(p.join(tmp.path, 'app_settings.json'))
          .writeAsStringSync('not json {');
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadLocale(), isNull);
      expect(await store.loadHoldConfirm(), isTrue); // default

      await store.saveLocale('zh');
      expect(await store.loadLocale(), 'zh');
      // A fresh instance re-reads disk: the save replaced the corrupt file.
      expect(await SettingsStore(_TmpStorage(tmp.path)).loadLocale(), 'zh');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('a load after two chained updates sees both keys', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadDeviceId(), isNull); // prime the cache first
      await store.saveDeviceId('device-1');
      await store.saveLocale('en');
      expect(await store.loadDeviceId(), 'device-1');
      expect(await store.loadLocale(), 'en');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('loads are served from the cache once read (single-writer store)',
      () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      await store.saveLocale('zh');
      expect(await store.loadLocale(), 'zh');

      // An out-of-band edit is deliberately NOT observed: this store is the
      // file's only writer (app-private dir), so loads hit disk once and
      // the cache is authoritative afterwards.
      File(p.join(tmp.path, 'app_settings.json'))
          .writeAsStringSync('{"locale":"en"}');
      expect(await store.loadLocale(), 'zh');
    } finally {
      await tmp.delete(recursive: true);
    }
  });
}
