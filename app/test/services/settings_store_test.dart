import 'dart:convert';
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

/// 注入瞬时 IO 故障:前 [failuresLeft] 次解析目录时抛异常,之后恢复正常。
/// SettingsStore 的读和写都要先过 maFilesDir,所以这一个开关能同时
/// 模拟"读失败"和"写失败"。
class _FlakyStorage extends _TmpStorage {
  int failuresLeft;
  _FlakyStorage(super.dir, {this.failuresLeft = 0});
  @override
  Future<String> maFilesDir() async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const FileSystemException('transient IO error');
    }
    return super.maFilesDir();
  }
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

  test('delete hold-to-confirm defaults to true and persists', () async {
    // 默认开:老安装升级后无 key 也要读成开(`!= false`),issue #8 的
    // 防误删长按确认才会对存量用户生效。
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadDeleteHold(), isTrue);
      await store.saveDeleteHold(false);
      expect(await store.loadDeleteHold(), isFalse);
      await store.saveDeleteHold(true);
      expect(await store.loadDeleteHold(), isTrue);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('block-screenshots defaults to FALSE and persists', () async {
    // The odd one out among the switches: an absent key must read as off, so
    // this asserts the `== true` reading rather than the `!= false` one the
    // neighbouring settings use. Getting that backwards would silently black
    // out screen sharing for every existing install on upgrade.
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadBlockScreenshots(), isFalse);
      await store.saveBlockScreenshots(true);
      expect(await store.loadBlockScreenshots(), isTrue);
      await store.saveBlockScreenshots(false);
      expect(await store.loadBlockScreenshots(), isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('privacy consent is versioned, and a pre-versioning install reads as v1',
      () async {
    // The migration that matters: installs from before versioning stored only
    // `privacy_accepted: true`. Reading that as "accepted the current
    // version" would silently carry consent across a notice that says
    // something different; reading it as 0 would re-onboard a long-time user
    // from scratch. It has to land on 1 — the version whose text they saw.
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadPrivacyAcceptedVersion(), 0); // never accepted

      File(p.join(tmp.path, 'app_settings.json'))
          .writeAsStringSync(jsonEncode({'privacy_accepted': true}));
      final legacy = SettingsStore(_TmpStorage(tmp.path));
      expect(await legacy.loadPrivacyAcceptedVersion(), 1);

      await legacy.savePrivacyAcceptedVersion(2);
      expect(await legacy.loadPrivacyAcceptedVersion(), 2);
      // The legacy flag is kept, so an older build does not re-prompt.
      final raw = jsonDecode(
              File(p.join(tmp.path, 'app_settings.json')).readAsStringSync())
          as Map<String, dynamic>;
      expect(raw['privacy_accepted'], isTrue);
      expect(raw['privacy_version'], 2);
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

  test(
      'REGRESSION: a transient read failure is not cached as {} — the next '
      'load sees the intact file again', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      // Seed real persisted values first.
      final seeder = SettingsStore(_TmpStorage(tmp.path));
      await seeder.saveLocale('zh');
      await seeder.saveEntitlementToken('jwt-raw');

      // First read hits the transient failure → defaults for THIS call only.
      final store = SettingsStore(_FlakyStorage(tmp.path, failuresLeft: 1));
      expect(await store.loadLocale(), isNull);

      // The failure cleared: the retry must see disk, not a poisoned {}
      // cache (which a later _update would persist, wiping every key).
      expect(await store.loadLocale(), 'zh');
      expect(await store.loadEntitlementToken(), 'jwt-raw');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test(
      'REGRESSION: a failed write is not published to the cache — loads '
      'reflect disk, and the next save persists cleanly', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final storage = _FlakyStorage(tmp.path);
      final store = SettingsStore(storage);
      await store.saveEntitlementToken('old-jwt'); // also primes the cache

      // The write fails in flight: the mutation never reached disk, so
      // memory must not keep serving it as if it had.
      storage.failuresLeft = 1;
      await store.saveEntitlementToken('phantom-jwt');
      expect(await store.loadEntitlementToken(), 'old-jwt');

      // And a later successful save starts from disk, not the phantom.
      await store.saveLocale('zh');
      expect(await store.loadEntitlementToken(), 'old-jwt');
      expect(
          await SettingsStore(_TmpStorage(tmp.path)).loadEntitlementToken(),
          'old-jwt');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test(
      'REGRESSION: an _update whose base read transiently fails does not '
      'overwrite the intact file with a single-key map', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      // A real, populated file on disk.
      final seeder = SettingsStore(_TmpStorage(tmp.path));
      await seeder.saveLocale('zh');
      await seeder.saveEntitlementToken('jwt-raw');
      await seeder.saveDeviceId('dev-1');

      // A fresh instance (empty cache): the very first thing it does is a
      // settings toggle whose base read fails transiently. It must abort the
      // write, not persist {skin: neon} over the token/device-id/locale.
      final store = SettingsStore(_FlakyStorage(tmp.path, failuresLeft: 1));
      await store.saveSkin('neon');

      final reader = SettingsStore(_TmpStorage(tmp.path));
      expect(await reader.loadEntitlementToken(), 'jwt-raw');
      expect(await reader.loadDeviceId(), 'dev-1');
      expect(await reader.loadLocale(), 'zh');
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test(
      'REGRESSION: loadDeviceId throws on a read failure rather than '
      'reporting the id as unset', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final seeder = SettingsStore(_TmpStorage(tmp.path));
      await seeder.saveDeviceId('dev-1');

      // Transient failure → throw, so deviceIdProvider never mistakes it for
      // first-run and mints a fresh id that would rebind Pro.
      final store = SettingsStore(_FlakyStorage(tmp.path, failuresLeft: 1));
      await expectLater(
          store.loadDeviceId(), throwsA(isA<SettingsReadException>()));
      // Recovered: the real id is returned, no minting happened.
      expect(await store.loadDeviceId(), 'dev-1');
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
