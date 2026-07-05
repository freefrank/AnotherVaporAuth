import 'dart:io';

import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// A concrete provider backed by a real temp directory, to exercise the atomic
/// + serialized writeFile path (MemoryStorageProvider overrides writeFile).
class _DiskProvider extends StorageProvider {
  final String dir;
  _DiskProvider(this.dir);
  @override
  Future<String> maFilesDir() async => dir;
}

void main() {
  group('sanitizeFilename', () {
    test('accepts the real maFile / manifest names', () {
      for (final ok in [
        'manifest.json',
        '76561198000000000.maFile',
        '76561198000000000.v2.maFile',
      ]) {
        expect(StorageProvider.sanitizeFilename(ok), ok);
      }
    });

    test('rejects traversal and absolute paths', () {
      for (final bad in [
        '',
        '.',
        '..',
        '../x.maFile',
        '../../etc/passwd',
        'a/b.maFile',
        r'a\b.maFile',
        '/etc/passwd',
        r'C:\Windows\x',
        'sub/dir',
        'has space.maFile',
      ]) {
        expect(() => StorageProvider.sanitizeFilename(bad), throwsArgumentError,
            reason: bad);
      }
    });
  });

  group('MemoryStorageProvider enforces the guard', () {
    test('write/read/delete reject unsafe names', () async {
      final s = MemoryStorageProvider();
      await s.writeFile('123.maFile', 'ok');
      expect(await s.readFile('123.maFile'), 'ok');

      expect(() => s.writeFile('../evil', 'x'), throwsArgumentError);
      expect(() => s.readFile('../evil'), throwsArgumentError);
      expect(() => s.deleteFile('../evil'), throwsArgumentError);
      expect(() => s.fileExists('../evil'), throwsArgumentError);
    });
  });

  group('atomic + serialized writeFile', () {
    late Directory tmp;
    late _DiskProvider provider;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ava_storage_test');
      provider = _DiskProvider(tmp.path);
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('concurrent writes to the same file never tear it or leak temps',
        () async {
      // Fire many overlapping writes with distinct, large contents to the same
      // filename; each must land atomically (the final file equals exactly one
      // of the inputs) with no leftover .tmp files.
      final inputs = [
        for (var i = 0; i < 20; i++) 'content-$i-${'x' * 5000}',
      ];
      await Future.wait(
          [for (final c in inputs) provider.writeFile('m.maFile', c)]);

      final finalContent = await provider.readFile('m.maFile');
      expect(inputs, contains(finalContent)); // intact, not torn/interleaved

      final leftovers = tmp
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty, reason: 'temp files should be cleaned up');
    });

    test('concurrent writes to different files all succeed', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++) provider.writeFile('$i.maFile', 'v$i'),
      ]);
      for (var i = 0; i < 10; i++) {
        expect(await provider.readFile('$i.maFile'), 'v$i');
      }
    });
  });

  group('portableOverride', () {
    test('returns exe-adjacent maFiles dir when portable.txt exists', () {
      final dir = StorageProvider.portableOverride(
          '/opt/ava', (path) => path == '/opt/ava/portable.txt');
      expect(dir, '/opt/ava/maFiles');
    });

    test('returns null without the marker', () {
      expect(StorageProvider.portableOverride('/opt/ava', (_) => false),
          isNull);
    });
  });
}
