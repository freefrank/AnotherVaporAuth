import 'dart:io';

import 'package:ava_installer/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The hazard these tests exist for: uninstall used to be
/// `Directory(dir).delete(recursive: true)` gated only on "ava.exe and data\
/// are present". Install into a folder that already holds your files — which
/// the free-text path field allows, and which many installers make safe by
/// appending their own subfolder — and uninstalling takes the folder with it.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ava_installer_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('validateInstallDir', () {
    test('accepts a fresh subfolder', () {
      expect(InstallEngine.validateInstallDir(p.join(tmp.path, 'AVA')), isNull);
    });

    test('rejects empty and relative paths', () {
      expect(InstallEngine.validateInstallDir(''), isNotNull);
      expect(InstallEngine.validateInstallDir('   '), isNotNull);
      expect(InstallEngine.validateInstallDir('AVA'), isNotNull);
      expect(InstallEngine.validateInstallDir('./AVA'), isNotNull);
    });

    test('rejects a volume root', () {
      final root = p.rootPrefix(p.normalize(tmp.path));
      expect(InstallEngine.validateInstallDir(root), isNotNull);
    });

    test('rejects the home directory itself but allows a subfolder of it', () {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null) return; // nothing to assert on this host
      expect(InstallEngine.validateInstallDir(home), isNotNull);
      expect(InstallEngine.validateInstallDir(p.join(home, 'ava-test-subdir')),
          isNull);
    });

    test('rejects a non-empty folder that is not one of ours', () {
      final dir = Directory(p.join(tmp.path, 'Documents'))..createSync();
      File(p.join(dir.path, 'thesis.docx')).writeAsStringSync('important');
      expect(InstallEngine.validateInstallDir(dir.path), isNotNull);
    });

    test('accepts re-installing over a previous AVA install', () {
      final dir = Directory(p.join(tmp.path, 'AVA'))..createSync();
      File(p.join(dir.path, InstallEngine.manifestName)).writeAsStringSync('');
      expect(InstallEngine.validateInstallDir(dir.path), isNull);
    });
  });

  group('resolveEntry', () {
    test('keeps ordinary entries inside the install folder', () {
      final got = InstallEngine.resolveEntry(tmp.path, 'data/icudtl.dat');
      expect(got, p.normalize(p.join(tmp.path, 'data', 'icudtl.dat')));
    });

    test('refuses to escape via .. or an absolute path', () {
      expect(InstallEngine.resolveEntry(tmp.path, '../evil.exe'), isNull);
      expect(InstallEngine.resolveEntry(tmp.path, 'a/../../evil.exe'), isNull);
      expect(InstallEngine.resolveEntry(tmp.path, '/etc/passwd'), isNull);
      expect(InstallEngine.resolveEntry(tmp.path, r'C:\Windows\evil.exe'), isNull);
    });
  });

  group('removeInstalled', () {
    test('REGRESSION: deletes only what the manifest lists', () async {
      final dir = Directory(p.join(tmp.path, 'Documents'))..createSync();
      // What the installer wrote…
      File(p.join(dir.path, 'ava.exe')).writeAsStringSync('app');
      Directory(p.join(dir.path, 'data')).createSync();
      File(p.join(dir.path, 'data', 'icudtl.dat')).writeAsStringSync('icu');
      File(p.join(dir.path, 'uninstall.exe')).writeAsStringSync('un');
      File(p.join(dir.path, InstallEngine.manifestName)).writeAsStringSync(
          ['ava.exe', 'data/icudtl.dat', 'uninstall.exe',
           InstallEngine.manifestName].join('\n'));
      // …and what the user had there all along.
      File(p.join(dir.path, 'thesis.docx')).writeAsStringSync('important');
      Directory(p.join(dir.path, 'photos')).createSync();
      File(p.join(dir.path, 'photos', 'cat.jpg')).writeAsStringSync('meow');

      await InstallEngine.removeInstalled(dir.path, log: (_) {});

      expect(File(p.join(dir.path, 'ava.exe')).existsSync(), isFalse);
      expect(Directory(p.join(dir.path, 'data')).existsSync(), isFalse);
      expect(File(p.join(dir.path, InstallEngine.manifestName)).existsSync(),
          isFalse);
      // The whole point:
      expect(File(p.join(dir.path, 'thesis.docx')).existsSync(), isTrue);
      expect(File(p.join(dir.path, 'photos', 'cat.jpg')).existsSync(), isTrue);
      expect(dir.existsSync(), isTrue);
    });

    test('removes the folder itself when nothing else was in it', () async {
      final dir = Directory(p.join(tmp.path, 'AVA'))..createSync();
      File(p.join(dir.path, 'ava.exe')).writeAsStringSync('app');
      File(p.join(dir.path, InstallEngine.manifestName))
          .writeAsStringSync(['ava.exe', InstallEngine.manifestName].join('\n'));

      await InstallEngine.removeInstalled(dir.path, log: (_) {});

      expect(dir.existsSync(), isFalse);
    });

    test('a manifest entry pointing outside the folder is ignored', () async {
      final dir = Directory(p.join(tmp.path, 'AVA'))..createSync();
      final bystander = File(p.join(tmp.path, 'bystander.txt'))
        ..writeAsStringSync('not yours');
      File(p.join(dir.path, 'ava.exe')).writeAsStringSync('app');
      File(p.join(dir.path, InstallEngine.manifestName)).writeAsStringSync(
          ['ava.exe', '../bystander.txt', InstallEngine.manifestName].join('\n'));

      await InstallEngine.removeInstalled(dir.path, log: (_) {});

      expect(bystander.existsSync(), isTrue);
    });

    test('with no manifest, falls back to the old guard and refuses a '
        'folder that is not an AVA install', () async {
      final dir = Directory(p.join(tmp.path, 'Documents'))..createSync();
      File(p.join(dir.path, 'thesis.docx')).writeAsStringSync('important');

      await expectLater(
          InstallEngine.removeInstalled(dir.path, log: (_) {}),
          throwsA(isA<StateError>()));
      expect(File(p.join(dir.path, 'thesis.docx')).existsSync(), isTrue);
    });
  });
}
