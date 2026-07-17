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

    test('deleteFile is chained behind a pending write to the same name',
        () async {
      // Fired without awaiting: the delete must queue behind the write, so
      // the final state is deterministic (file gone), not a race where the
      // delete lands between the write's temp and rename.
      final w = provider.writeFile('d.maFile', 'x');
      final d = provider.deleteFile('d.maFile');
      await Future.wait([w, d]);
      expect(await provider.fileExists('d.maFile'), isFalse);

      // And the reverse order: delete queued first, write recreates.
      await provider.writeFile('d.maFile', 'x');
      final d2 = provider.deleteFile('d.maFile');
      final w2 = provider.writeFile('d.maFile', 'y');
      await Future.wait([d2, w2]);
      expect(await provider.readFile('d.maFile'), 'y');
    });
  });

  group('lastModified', () {
    test('disk provider reports a time for existing files, null otherwise',
        () async {
      final tmp = await Directory.systemTemp.createTemp('ava_mtime_test');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final provider = _DiskProvider(tmp.path);
      await provider.writeFile('a.maFile', 'x');
      expect(await provider.lastModified('a.maFile'), isNotNull);
      expect(await provider.lastModified('missing.maFile'), isNull);
    });

    test('memory provider orders by write sequence and forgets on delete',
        () async {
      final s = MemoryStorageProvider();
      await s.writeFile('a.maFile', '1');
      await s.writeFile('b.maFile', '2');
      final a1 = (await s.lastModified('a.maFile'))!;
      final b1 = (await s.lastModified('b.maFile'))!;
      expect(b1.isAfter(a1), isTrue);

      // A rewrite makes the file the newest again.
      await s.writeFile('a.maFile', '3');
      final a2 = (await s.lastModified('a.maFile'))!;
      expect(a2.isAfter(b1), isTrue);

      await s.deleteFile('a.maFile');
      expect(await s.lastModified('a.maFile'), isNull);
      // Directly seeded files (no write) have no sequence either.
      s.files['seeded.maFile'] = 'x';
      expect(await s.lastModified('seeded.maFile'), isNull);
    });
  });

  group('replaceFileAtomic', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ava_replace_atomic_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('overwrites an existing file and leaves no temps', () async {
      final path = '${tmp.path}/app_settings.json';
      await File(path).writeAsString('old');

      await StorageProvider.replaceFileAtomic(path, 'new');

      expect(await File(path).readAsString(), 'new');
      final leftovers = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('a failed write throws, leaves the target untouched and no temp',
        () async {
      // Nonexistent directory: the temp write itself fails.
      final path = '${tmp.path}/no-such-dir/app_settings.json';
      await expectLater(
          StorageProvider.replaceFileAtomic(path, 'x'), throwsA(anything));
      expect(await File(path).exists(), isFalse);
      final leftovers = tmp
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });
}
