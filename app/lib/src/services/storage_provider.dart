import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Abstracts where the `maFiles/` directory lives per platform.
///
/// - Desktop & mobile: the app's per-user application-support directory (stable
///   across upgrades / bundle replacement). Older desktop builds kept it next
///   to the executable; that store is migrated over on first run.
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

  // Serializes writes to the same filename. Two concurrent saves — e.g.
  // refreshSessions and refreshAvatars both persisting the manifest — must not
  // race on the temp file or lose an update; this chains them per filename.
  final Map<String, Future<void>> _writeChains = {};
  // Monotonic suffix so each in-flight write uses its own temp file (a shared
  // "$path.tmp" could be clobbered or renamed out from under a sibling write).
  int _tmpSeq = 0;

  Future<void> writeFile(String filename, String contents) async {
    final prev = _writeChains[filename] ?? Future<void>.value();
    final done = Completer<void>();
    _writeChains[filename] = done.future;
    await prev.catchError((_) {}); // wait our turn; ignore a prior failure
    try {
      await _writeAtomic(filename, contents);
    } finally {
      done.complete();
      if (identical(_writeChains[filename], done.future)) {
        _writeChains.remove(filename);
      }
    }
  }

  Future<void> _writeAtomic(String filename, String contents) async {
    await ensureDir();
    final path = await filePath(filename);
    // Write to a unique sibling temp file then rename over the target: a crash
    // or partial write leaves the old file intact instead of a truncated one,
    // so the manifest and payloads can't be torn mid-write. Rename within a
    // directory is atomic on the platforms we target.
    final tmp = File('$path.${_tmpSeq++}.tmp');
    try {
      await tmp.writeAsString(contents, flush: true);
      await tmp.rename(path);
    } catch (_) {
      // Clean up a leftover temp on failure so it can't masquerade as data.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
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
    // Store in the per-user application-support directory, NOT next to the
    // executable. An exe-adjacent folder is lost or emptied by app-bundle
    // replacement, package-manager upgrades, or running from a temp/extracted
    // location — the user would see an empty vault or lose data.
    final support = await getApplicationSupportDirectory();
    final dir = p.join(support.path, 'maFiles');
    await _migrateFromExeAdjacent(dir);
    return _cached = dir;
  }

  /// One-time move of an existing store from the legacy exe-adjacent location
  /// (used by older builds) into the stable [stableDir]. Runs only when the
  /// stable dir has no manifest yet but the legacy one does. Copies (doesn't
  /// delete the source) so an interrupted migration can't lose data.
  Future<void> _migrateFromExeAdjacent(String stableDir) async {
    try {
      if (await File(p.join(stableDir, 'manifest.json')).exists()) return;
      final legacyDir = p.join(p.dirname(Platform.resolvedExecutable), 'maFiles');
      if (!await File(p.join(legacyDir, 'manifest.json')).exists()) return;
      await Directory(stableDir).create(recursive: true);
      for (final f in Directory(legacyDir).listSync().whereType<File>()) {
        await f.copy(p.join(stableDir, p.basename(f.path)));
      }
    } catch (_) {
      // Best-effort: a failed migration falls back to a fresh empty store
      // rather than crashing; the legacy files remain for manual recovery.
    }
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
