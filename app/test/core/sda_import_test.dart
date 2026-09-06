import 'dart:convert';

import 'package:ava/src/core/crypto/ma_file_crypto.dart';
import 'package:ava/src/core/sda_import.dart';
import 'package:flutter_test/flutter_test.dart';

/// A believable maFile payload — only the fields the import path reads.
String _maFile(int steamId) => jsonEncode({
      'shared_secret': 'c2hhcmVk',
      'identity_secret': 'aWRlbnQ=',
      'account_name': 'user$steamId',
      'Session': {'SteamID': steamId},
    });

/// Builds an SDA-shaped manifest + the on-disk files for [steamIds].
/// Encrypting here goes through MaFileCrypto, the same code SDA's own
/// FileEncryptor is byte-compatible with.
({String manifest, Map<String, String> files}) _bundle(
  List<int> steamIds, {
  String? passKey,
}) {
  final entries = <Map<String, dynamic>>[];
  final files = <String, String>{};
  for (final id in steamIds) {
    final name = '$id.maFile';
    final plain = _maFile(id);
    if (passKey == null) {
      entries.add({'filename': name, 'steamid': id});
      files[name] = plain;
    } else {
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      entries.add({
        'filename': name,
        'steamid': id,
        'encryption_salt': salt,
        'encryption_iv': iv,
      });
      // Low round count: these tests exercise the pairing and error paths, not
      // PBKDF2 itself — ma_file_crypto_test.dart locks that to RFC 6070.
      files[name] = MaFileCrypto.encrypt(passKey, salt, iv, plain);
    }
  }
  return (
    manifest: jsonEncode({'encrypted': passKey != null, 'entries': entries}),
    files: files,
  );
}

void main() {
  test('imports multiple plaintext maFiles without a manifest', () async {
    final read = await readSdaBundle(
      files: {
        'first.maFile': _maFile(1),
        'SECOND.MAFILE': _maFile(2),
        'broken.maFile': 'invalid',
        'notes.txt': 'not an account',
      },
    );
    expect(read.imported.map((r) => r.plaintext), [_maFile(1), _maFile(2)]);
    expect(read.failed.single.entry.filename, 'broken.maFile');
    expect(read.unlistedFiles, ['notes.txt']);
    expect(read.wrongPassKey, isFalse);
  });

  test(
    'encrypted data without manifest is not imported as plaintext',
    () async {
      final b = _bundle([1], passKey: 'secret');
      final read = await readSdaBundle(files: b.files);
      expect(read.imported, isEmpty);
      expect(read.failed.single.problem, SdaEntryProblem.notReadable);
      expect(read.wrongPassKey, isFalse);
    },
  );

  group('SdaManifest.parse', () {
    test('reads entries and the encrypted flag', () {
      final b = _bundle([1, 2], passKey: 'hunter2');
      final m = SdaManifest.parse(b.manifest);
      expect(m.encrypted, isTrue);
      expect(m.entries.length, 2);
      expect(m.entries.first.hasCryptoParams, isTrue);
    });

    test('an unencrypted manifest carries no crypto params', () {
      final m = SdaManifest.parse(_bundle([1]).manifest);
      expect(m.encrypted, isFalse);
      expect(m.entries.single.hasCryptoParams, isFalse);
    });

    test('per-entry salt/iv win over a missing encrypted flag', () {
      // Older SDA manifests omit the flag but still ship ciphertext. Trusting
      // the flag alone would hand base64 to the JSON parser.
      final b = _bundle([7], passKey: 'k');
      final stripped = jsonDecode(b.manifest) as Map<String, dynamic>
        ..remove('encrypted');
      expect(SdaManifest.parse(jsonEncode(stripped)).encrypted, isTrue);
    });

    test('steamid given as a string still parses', () {
      final m = SdaManifest.parse(jsonEncode({
        'encrypted': false,
        'entries': [
          {'filename': 'a.maFile', 'steamid': '76561198000000001'},
        ],
      }));
      expect(m.entries.single.steamId, 76561198000000001);
    });

    test('rejects input that is not an SDA manifest', () {
      expect(() => SdaManifest.parse('not json'),
          throwsA(isA<SdaManifestException>()));
      expect(() => SdaManifest.parse('{"entries":[]}'),
          throwsA(isA<SdaManifestException>()));
      expect(() => SdaManifest.parse('{"foo":1}'),
          throwsA(isA<SdaManifestException>()));
    });
  });

  group('readSdaBundle — encrypted', () {
    test('right passkey yields every account', () async {
      final b = _bundle([11, 22], passKey: 'correct horse');
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: b.files,
        passKey: 'correct horse',
      );
      expect(r.wrongPassKey, isFalse);
      expect(r.imported.length, 2);
      expect(jsonDecode(r.imported.first.plaintext!)['Session']['SteamID'], 11);
    });

    test('wrong passkey is reported as such, not as corrupt files', () async {
      final b = _bundle([11, 22], passKey: 'correct horse');
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: b.files,
        passKey: 'wrong',
      );
      expect(r.wrongPassKey, isTrue);
      expect(r.imported, isEmpty);
      expect(r.failed.every((f) => f.problem == SdaEntryProblem.notReadable),
          isTrue);
    });

    test('one corrupt file among good ones is not a wrong passkey', () async {
      final b = _bundle([11, 22], passKey: 'pk');
      final files = Map<String, String>.from(b.files)
        ..['22.maFile'] = base64.encode(List.filled(32, 0));
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: files,
        passKey: 'pk',
      );
      expect(r.wrongPassKey, isFalse,
          reason: 'a readable sibling proves the key was right');
      expect(r.imported.length, 1);
      expect(r.failed.single.entry.filename, '22.maFile');
    });

    test('a row missing its iv fails alone, not the batch', () async {
      final b = _bundle([11, 22], passKey: 'pk');
      final manifest = jsonDecode(b.manifest) as Map<String, dynamic>;
      (manifest['entries'] as List)[1]['encryption_iv'] = '';
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(jsonEncode(manifest)),
        files: b.files,
        passKey: 'pk',
      );
      expect(r.imported.length, 1);
      expect(r.failed.single.problem, SdaEntryProblem.missingCryptoParams);
      expect(r.wrongPassKey, isFalse);
    });

    test('a file listed but not selected is named, not silently dropped',
        () async {
      final b = _bundle([11, 22], passKey: 'pk');
      final files = Map<String, String>.from(b.files)..remove('22.maFile');
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: files,
        passKey: 'pk',
      );
      expect(r.imported.length, 1);
      expect(r.failed.single.problem, SdaEntryProblem.fileNotSelected);
      expect(r.failed.single.entry.filename, '22.maFile');
    });

    test('selecting nothing listed is not reported as a bad passkey', () async {
      // Every row unmatched means zero decrypt attempts. Calling that a wrong
      // password would send the user off to re-type a password that was fine.
      final b = _bundle([11], passKey: 'pk');
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: const {},
        passKey: 'pk',
      );
      expect(r.wrongPassKey, isFalse);
      expect(r.failed.single.problem, SdaEntryProblem.fileNotSelected);
    });

    test('filename case differences still match', () async {
      final b = _bundle([11], passKey: 'pk');
      final files = {'11.MAFILE': b.files['11.maFile']!};
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: files,
        passKey: 'pk',
      );
      expect(r.imported.length, 1);
    });
  });

  group('readSdaBundle — unencrypted', () {
    test('plain files import without a passkey', () async {
      final b = _bundle([5, 6]);
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: b.files,
      );
      expect(r.imported.length, 2);
      expect(r.wrongPassKey, isFalse);
    });

    test('a non-JSON file is flagged, not imported', () async {
      final b = _bundle([5]);
      final r = await readSdaBundle(
        manifest: SdaManifest.parse(b.manifest),
        files: {'5.maFile': 'garbage'},
      );
      expect(r.imported, isEmpty);
      expect(r.failed.single.problem, SdaEntryProblem.notReadable);
      expect(r.wrongPassKey, isFalse,
          reason: 'nothing was encrypted, so no key can be wrong');
    });
  });

  test('files the manifest never mentions are surfaced', () async {
    final b = _bundle([5]);
    final files = Map<String, String>.from(b.files)
      ..['manifest.json'] = b.manifest
      ..['notes.txt'] = 'hello';
    final r = await readSdaBundle(
      manifest: SdaManifest.parse(b.manifest),
      files: files,
    );
    expect(r.imported.length, 1);
    expect(r.unlistedFiles, ['notes.txt'],
        reason: 'manifest.json itself is expected in the selection');
  });
}
