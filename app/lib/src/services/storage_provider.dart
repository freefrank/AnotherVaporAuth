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

  /// Absolute path to the `maFiles/` directory.
  Future<String> maFilesDir();

  Future<String> manifestPath() async =>
      p.join(await maFilesDir(), 'manifest.json');

  Future<String> filePath(String filename) async =>
      p.join(await maFilesDir(), filename);

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
  Future<bool> fileExists(String filename) async => files.containsKey(filename);
  @override
  Future<String> readFile(String filename) async => files[filename]!;
  @override
  Future<void> writeFile(String filename, String contents) async =>
      files[filename] = contents;
  @override
  Future<void> deleteFile(String filename) async => files.remove(filename);
  @override
  Future<List<String>> listFiles({String extension = '.maFile'}) async =>
      files.keys.where((k) => k.endsWith(extension)).toList();
}
