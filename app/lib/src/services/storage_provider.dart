import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Abstracts where the `maFiles/` directory lives per platform.
///
/// - Desktop: next to the executable (matches the legacy .NET layout so an
///   existing install can be pointed at the same folder for migration).
/// - Mobile: the app's private support directory.
abstract class StorageProvider {
  StorageProvider();

  /// Picks the right provider for the current platform.
  factory StorageProvider.forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _MobileStorageProvider();
    }
    return _DesktopStorageProvider();
  }

  /// Validates a filename that came (ultimately) from a manifest — an
  /// attacker-tamperable file — before it is joined onto [maFilesDir] for a
  /// read/write/delete. A crafted `filename` like `../../x` or an absolute
  /// path would otherwise let a tampered manifest reach files outside the
  /// `maFiles/` sandbox (path traversal). Returns the name unchanged when
  /// safe; throws [ArgumentError] otherwise.
  static String sanitizeFilename(String name) {
    // Reject spaces and control characters (incl. NUL / poison-null-byte)
    // up front, then any path structure.
    final hasBadChar = name.codeUnits.any((c) => c <= 0x20 || c == 0x7f);
    final bad = name.isEmpty ||
        name == '.' ||
        name == '..' ||
        hasBadChar ||
        name.contains('/') ||
        name.contains(r'\') ||
        p.isAbsolute(name) ||
        p.basename(name) != name; // any directory component
    if (bad) {
      throw ArgumentError.value(name, 'filename', 'unsafe storage filename');
    }
    return name;
  }

  /// Absolute path to the `maFiles/` directory.
  Future<String> maFilesDir();

  Future<String> manifestPath() async =>
      p.join(await maFilesDir(), 'manifest.json');

  Future<String> filePath(String filename) async =>
      p.join(await maFilesDir(), sanitizeFilename(filename));

  Future<bool> dirExists() async => Directory(await maFilesDir()).exists();

  Future<void> ensureDir() async {
    final dir = Directory(await maFilesDir());
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<bool> fileExists(String filename) async =>
      File(await filePath(filename)).exists();

  Future<String> readFile(String filename) async =>
      File(await filePath(filename)).readAsString();

  Future<void> writeFile(String filename, String contents) async {
    await ensureDir();
    await File(await filePath(filename)).writeAsString(contents);
  }

  Future<void> deleteFile(String filename) async {
    final f = File(await filePath(filename));
    if (await f.exists()) await f.delete();
  }

  Future<List<String>> listFiles({String extension = '.maFile'}) async {
    final dir = Directory(await maFilesDir());
    if (!await dir.exists()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => name.endsWith(extension))
        .toList();
  }
}

class _DesktopStorageProvider extends StorageProvider {
  String? _cached;

  @override
  Future<String> maFilesDir() async {
    if (_cached != null) return _cached!;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return _cached = p.join(exeDir, 'maFiles');
  }
}

class _MobileStorageProvider extends StorageProvider {
  String? _cached;

  @override
  Future<String> maFilesDir() async {
    if (_cached != null) return _cached!;
    final dir = await getApplicationSupportDirectory();
    return _cached = p.join(dir.path, 'maFiles');
  }
}

/// In-memory provider for tests.
class MemoryStorageProvider extends StorageProvider {
  final Map<String, String> files = {};
  final String _dir;
  MemoryStorageProvider([this._dir = '/memory/maFiles']);

  @override
  Future<String> maFilesDir() async => _dir;

  // Treat an empty store as "no directory yet" so load() creates a fresh
  // manifest instead of throwing a parse exception.
  @override
  Future<bool> dirExists() async => files.isNotEmpty;
  @override
  Future<void> ensureDir() async {}
  @override
  Future<bool> fileExists(String filename) async =>
      files.containsKey(StorageProvider.sanitizeFilename(filename));
  @override
  Future<String> readFile(String filename) async =>
      files[StorageProvider.sanitizeFilename(filename)]!;
  @override
  Future<void> writeFile(String filename, String contents) async =>
      files[StorageProvider.sanitizeFilename(filename)] = contents;
  @override
  Future<void> deleteFile(String filename) async =>
      files.remove(StorageProvider.sanitizeFilename(filename));
  @override
  Future<List<String>> listFiles({String extension = '.maFile'}) async =>
      files.keys.where((k) => k.endsWith(extension)).toList();
}
