import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/storage_provider.dart';

/// Tiny key/value store for non-secret app preferences (e.g. UI language),
/// kept next to the maFiles directory as `app_settings.json`.
class SettingsStore {
  final StorageProvider storage;
  SettingsStore(this.storage);

  Future<File> _file() async {
    final dir = await storage.maFilesDir();
    return File(p.join(p.dirname(dir), 'app_settings.json'));
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(data));
    } catch (_) {
      // best-effort; preferences are non-critical
    }
  }

  Future<String?> loadLocale() async => (await _read())['locale'] as String?;

  Future<void> saveLocale(String? code) async {
    final data = await _read();
    if (code == null) {
      data.remove('locale');
    } else {
      data['locale'] = code;
    }
    await _write(data);
  }

  /// Whether the user has accepted the Privacy Policy (first-run gate).
  Future<bool> loadPrivacyAccepted() async =>
      (await _read())['privacy_accepted'] == true;

  Future<void> savePrivacyAccepted(bool accepted) async {
    final data = await _read();
    data['privacy_accepted'] = accepted;
    await _write(data);
  }

  /// Whether the first-run gesture tutorial has been shown (home screen).
  Future<bool> loadTutorialSeen() async =>
      (await _read())['tutorial_seen'] == true;

  Future<void> saveTutorialSeen() async {
    final data = await _read();
    data['tutorial_seen'] = true;
    await _write(data);
  }

  /// Clears the seen flag so the tutorial replays (settings → replay).
  Future<void> resetTutorialSeen() async {
    final data = await _read();
    data.remove('tutorial_seen');
    await _write(data);
  }

  /// UI theme variant: 'neon' (default) or 'pixel'.
  Future<String?> loadTheme() async => (await _read())['theme'] as String?;

  Future<void> saveTheme(String variant) async {
    final data = await _read();
    data['theme'] = variant;
    await _write(data);
  }
}
