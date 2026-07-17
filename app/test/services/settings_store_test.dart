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
}
