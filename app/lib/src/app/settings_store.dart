import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/storage_provider.dart';

/// Thrown by the strict read path when app_settings.json exists but could not
/// be read/parsed (a transient IO error, a momentary decode failure on an
/// otherwise-intact file). Callers that would otherwise overwrite the file or
/// mint fresh identity must abort rather than act on a fabricated empty store.
class SettingsReadException implements Exception {
  const SettingsReadException();
  @override
  String toString() => 'SettingsReadException';
}

/// Tiny key/value store for non-secret app preferences (e.g. UI language),
/// kept next to the maFiles directory as `app_settings.json`.
class SettingsStore {
  final StorageProvider storage;
  SettingsStore(this.storage);

  Future<File> _file() async {
    final dir = await storage.maFilesDir();
    return File(p.join(p.dirname(dir), 'app_settings.json'));
  }

  // Read-through cache for the whole file: startup does ~10 independent
  // load*() calls and every one used to re-read + re-decode the same tiny
  // JSON. Safe because this store is the file's only writer (the app-private
  // dir sees no external edits) and _update publishes to it after each write.
  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _read() async {
    final c = _cache;
    if (c != null) return c;
    final fresh = await _readDisk();
    // Cache only a real disk result. A transient IO/parse failure (null)
    // must not poison the cache as {}: a later _update would read-modify-
    // write that empty map and wipe every other key (locale, device id,
    // entitlement JWT) from a file that is actually intact.
    if (fresh != null) _cache = fresh;
    return fresh ?? const {};
  }

  /// Like [_read] but throws [SettingsReadException] instead of collapsing a
  /// read failure to `{}`. Used by paths where an empty map is a destructive
  /// decision: [_update] (which would else overwrite an intact file with a
  /// single-key map) and device-id resolution (which would else mint a fresh
  /// id and rebind Pro). A genuinely absent file still returns `{}`.
  Future<Map<String, dynamic>> _readStrict() async {
    final c = _cache;
    if (c != null) return c;
    final fresh = await _readDisk();
    if (fresh == null) throw const SettingsReadException();
    _cache = fresh;
    return fresh;
  }

  /// `{}` when the store holds nothing recoverable — the file is absent, or
  /// its content is unparseable (writes are atomic temp+rename, so a parse
  /// failure means genuinely corrupt content, not a half-written file, and is
  /// safe to treat as empty and overwrite). `null` ONLY on an IO failure
  /// (couldn't read the file at all), which may be transient over an intact
  /// file — the strict callers refuse to overwrite/mint on null.
  Future<Map<String, dynamic>?> _readDisk() async {
    final String contents;
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      contents = await f.readAsString();
    } catch (_) {
      return null;
    }
    try {
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Returns whether the write actually landed on disk.
  Future<bool> _write(Map<String, dynamic> data) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      // Atomic replace (temp + flush + rename): this file carries the
      // entitlement JWT and the device id Pro is bound to — a torn write
      // must never truncate it.
      await StorageProvider.replaceFileAtomic(f.path, jsonEncode(data));
      return true;
    } catch (_) {
      // best-effort; a failed write leaves the previous contents intact
      return false;
    }
  }

  // Serializes every read-modify-write against app_settings.json: two quick
  // toggles (e.g. the adjacent hold-confirm / haptics switches) must not
  // interleave their read and write phases, or the second write silently
  // drops the first one's value.
  Future<void> _chain = Future.value();

  Future<void> _update(void Function(Map<String, dynamic> data) mutate) {
    final task = _chain.then((_) async {
      // Establish the current file contents strictly: if the read failed we
      // must NOT write, or a single-key mutation over a fabricated {} would
      // overwrite an intact file and drop the entitlement token / device id.
      // The setting re-applies on its next change once the read recovers.
      final Map<String, dynamic> base;
      try {
        base = await _readStrict();
      } on SettingsReadException {
        return;
      }
      // Mutate a copy and publish it to the cache only after the write, so
      // concurrent loads never observe a half-applied mutation.
      final data = Map<String, dynamic>.of(base);
      mutate(data);
      if (await _write(data)) {
        _cache = data;
      } else {
        // The write never landed: drop the cache so the next read goes back
        // to the still-intact file instead of serving (and later persisting)
        // a mutation that only ever existed in memory.
        _cache = null;
      }
    });
    // Keep the chain alive even if this update fails.
    _chain = task.catchError((_) {});
    return task;
  }

  Future<String?> loadLocale() async => (await _read())['locale'] as String?;

  Future<void> saveLocale(String? code) => _update((data) {
        if (code == null) {
          data.remove('locale');
        } else {
          data['locale'] = code;
        }
      });

  /// Which revision of the Privacy Policy notice the user has accepted.
  ///
  /// `0` = never accepted. Versioned rather than a boolean so a later change
  /// to what the notice *says* can ask again instead of silently relying on
  /// consent given to different wording — which is exactly what happened
  /// through v1, whose text claimed AVA had no backend of its own.
  ///
  /// Migration: installs from before versioning stored `privacy_accepted:
  /// true` and nothing else. That reads as **v1**, not as the current
  /// version, so those users get the "policy updated" screen rather than
  /// either being re-onboarded from scratch or silently carried over.
  Future<int> loadPrivacyAcceptedVersion() async {
    final data = await _read();
    final v = data['privacy_version'];
    if (v is int) return v;
    return data['privacy_accepted'] == true ? 1 : 0;
  }

  /// Records acceptance of [version]. The legacy boolean is written too, so
  /// downgrading to an older build does not re-prompt from scratch.
  Future<void> savePrivacyAcceptedVersion(int version) => _update((data) {
        data['privacy_version'] = version;
        data['privacy_accepted'] = true;
      });

  /// Launch-time update check (v1.3). On by default — absence of the key
  /// means enabled; only an explicit `false` disables. The check itself is a
  /// single GET against a no-logging endpoint; the toggle exists for people
  /// who want zero non-essential connections regardless.
  Future<bool> loadUpdateCheckEnabled() async =>
      (await _read())['update_check_auto'] != false;

  Future<void> saveUpdateCheckEnabled(bool enabled) =>
      _update((data) => data['update_check_auto'] = enabled);


  /// Whether the one-time post-import backup reminder has been shown.
  Future<bool> loadBackupReminderShown() async =>
      (await _read())['backup_reminder_shown'] == true;

  Future<void> saveBackupReminderShown() =>
      _update((data) => data['backup_reminder_shown'] = true);

  /// Whether the user has agreed to the debug-log attachment notice (the
  /// one-time prompt shown when first ticking "attach debug log" in feedback).
  Future<bool> loadLogConsentShown() async =>
      (await _read())['log_consent_shown'] == true;

  Future<void> saveLogConsentShown() =>
      _update((data) => data['log_consent_shown'] = true);

  /// Whether the first-run gesture tutorial has been shown (home screen).
  Future<bool> loadTutorialSeen() async =>
      (await _read())['tutorial_seen'] == true;

  Future<void> saveTutorialSeen() =>
      _update((data) => data['tutorial_seen'] = true);

  /// Clears the seen flag so the tutorial replays (settings → replay).
  Future<void> resetTutorialSeen() =>
      _update((data) => data.remove('tutorial_seen'));

  /// Styled skin: 'none' | 'neon' | 'pixel'. Falls back to the legacy
  /// single 'theme' key ('neon'/'pixel'/'dark'/'light') for older installs.
  /// Desktop window geometry. Deliberately **not** in
  /// [AppSettingsPort.snapshot]'s whitelist: settings sync is per-account, not
  /// per-machine, and adopting a 2560px window from the desktop would leave a
  /// laptop with a window it cannot see.
  Future<Object?> loadWindowGeometry() async =>
      (await _read())['window_geometry'];

  Future<void> saveWindowGeometry(Map<String, dynamic> value) =>
      _update((d) => d['window_geometry'] = value);

  Future<String?> loadSkin() async {
    final data = await _read();
    final skin = data['skin'] as String?;
    if (skin != null) return skin;
    return switch (data['theme'] as String?) {
      'neon' => 'neon',
      'pixel' => 'pixel',
      'dark' || 'light' => 'none',
      _ => null,
    };
  }

  Future<void> saveSkin(String skin) => _update((data) => data['skin'] = skin);

  /// Plain-look brightness: 'system' | 'dark' | 'light'. Migrates the legacy
  /// 'theme' key the same way as [loadSkin].
  Future<String?> loadBrightnessMode() async {
    final data = await _read();
    final mode = data['brightness_mode'] as String?;
    if (mode != null) return mode;
    return switch (data['theme'] as String?) {
      'dark' => 'dark',
      'light' => 'light',
      _ => null,
    };
  }

  Future<void> saveBrightnessMode(String mode) =>
      _update((data) => data['brightness_mode'] = mode);

  // The pre-0.84 loadTheme/saveTheme pair is gone: the legacy 'theme' key
  // lives on only as the read-only migration source inside loadSkin /
  // loadBrightnessMode — writing it again would corrupt those switches.

  /// The stored entitlement JWT (Pro/VIP), verbatim. Not a secret: it is
  /// signature-protected and device-bound, so plain app_settings.json is fine.
  Future<String?> loadEntitlementToken() async =>
      (await _read())['entitlement_token'] as String?;

  Future<void> saveEntitlementToken(String raw) =>
      _update((data) => data['entitlement_token'] = raw);

  Future<void> clearEntitlementToken() =>
      _update((data) => data.remove('entitlement_token'));

  /// Whether the one-time "your skin is now a Pro perk" migration notice
  /// has been shown (0.90 upgrade path).
  Future<bool> loadSkinProNoticeShown() async =>
      (await _read())['skin_pro_notice_shown'] == true;

  Future<void> saveSkinProNoticeShown() =>
      _update((data) => data['skin_pro_notice_shown'] = true);

  /// Stable per-install device id used for entitlement device binding.
  /// Strict: throws [SettingsReadException] on a read failure rather than
  /// returning null, so a transient error is never mistaken for "no id yet"
  /// (which would mint a fresh id and rebind Pro to a device the worker never
  /// activated). Returns null only when the id is genuinely unset.
  Future<String?> loadDeviceId() async =>
      (await _readStrict())['device_id'] as String?;

  Future<void> saveDeviceId(String id) =>
      _update((data) => data['device_id'] = id);

  /// UI text size step: 'small' (default) | 'medium' | 'large'.
  Future<String?> loadTextSize() async =>
      (await _read())['text_size'] as String?;

  Future<void> saveTextSize(String size) =>
      _update((data) => data['text_size'] = size);

  /// 长按确认开关（默认开）。关闭后单条接受退回普通点按；
  /// 批量“全部接受”保留弹窗二次确认作为安全底线。
  Future<bool> loadHoldConfirm() async =>
      (await _read())['hold_confirm'] != false;

  Future<void> saveHoldConfirm(bool enabled) =>
      _update((data) => data['hold_confirm'] = enabled);

  /// 全局触觉反馈开关（默认开）：长按 tick/完成 impact 及现有触觉调用点。
  Future<bool> loadHaptics() async => (await _read())['haptics'] != false;

  Future<void> saveHaptics(bool enabled) =>
      _update((data) => data['haptics'] = enabled);

  /// 阻止截屏/录屏开关（Android FLAG_SECURE，**默认关**）。
  /// 与上面几个「默认开」的开关相反：缺省即 false，所以用 `== true`。
  Future<bool> loadBlockScreenshots() async =>
      (await _read())['block_screenshots'] == true;

  Future<void> saveBlockScreenshots(bool enabled) =>
      _update((data) => data['block_screenshots'] = enabled);
}
