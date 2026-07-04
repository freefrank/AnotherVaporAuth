import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
