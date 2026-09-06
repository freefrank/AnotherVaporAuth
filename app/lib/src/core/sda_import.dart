/// Reading a Steam Desktop Authenticator `maFiles/` folder.
///
/// SDA keeps a `manifest.json` next to the account files. When the user turned
/// on SDA's encryption — which SDA's own README calls "highly recommended" —
/// each `*.maFile` on disk is **base64 ciphertext, not JSON**, and the
/// parameters needed to decrypt it are *not in the file*: the salt and IV live
/// in that account's manifest entry.
///
/// That is the whole reason this module exists. A lone encrypted `.maFile`
/// cannot be imported by anyone, ever — without the manifest there is nothing
/// to derive the key with. Encrypted imports need both; plaintext maFiles
/// can be imported without a manifest.
///
/// Everything here is pure: no Flutter, no file system. The UI layer reads the
/// bytes and shows the errors; the decisions are all testable without either.
library;

import 'dart:convert';

import 'crypto/ma_file_crypto.dart';

/// One account's row in `manifest.json`.
class SdaManifestEntry {
  const SdaManifestEntry({
    required this.filename,
    required this.steamId,
    this.salt,
    this.iv,
  });

  final String filename;
  final int steamId;

  /// `encryption_salt` — base64, 8 bytes. Null on an unencrypted manifest.
  final String? salt;

  /// `encryption_iv` — base64, 16 bytes. Null on an unencrypted manifest.
  final String? iv;

  bool get hasCryptoParams =>
      (salt?.isNotEmpty ?? false) && (iv?.isNotEmpty ?? false);
}

/// Thrown when the selected manifest is not an SDA manifest at all.
class SdaManifestException implements Exception {
  SdaManifestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A parsed SDA `manifest.json`.
class SdaManifest {
  const SdaManifest({required this.encrypted, required this.entries});

  final bool encrypted;
  final List<SdaManifestEntry> entries;

  static SdaManifest parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw SdaManifestException('manifest.json is not valid JSON');
    }
    if (decoded is! Map) {
      throw SdaManifestException('manifest.json is not a JSON object');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw SdaManifestException('manifest.json has no "entries" list');
    }
    final entries = <SdaManifestEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) continue;
      final filename = (raw['filename'] as Object?)?.toString() ?? '';
      if (filename.isEmpty) continue;
      entries.add(SdaManifestEntry(
        filename: filename,
        // SDA writes steamid as a JSON number; tolerate a string too, since
        // third-party tools that rewrite manifests are not consistent here.
        steamId: switch (raw['steamid']) {
          final int v => v,
          final String v => int.tryParse(v) ?? 0,
          _ => 0,
        },
        salt: (raw['encryption_salt'] as Object?)?.toString(),
        iv: (raw['encryption_iv'] as Object?)?.toString(),
      ));
    }
    if (entries.isEmpty) {
      throw SdaManifestException('manifest.json lists no accounts');
    }
    // `encrypted` is the manifest's own flag, but a manifest written by an
    // older SDA can omit it while still carrying per-entry salt/iv. Trust the
    // parameters over the flag: if they are there, the files are ciphertext.
    final flagged = decoded['encrypted'] == true;
    return SdaManifest(
      encrypted: flagged || entries.every((e) => e.hasCryptoParams),
      entries: entries,
    );
  }
}

/// Why one account in the bundle could not be imported.
enum SdaEntryProblem {
  /// Listed in the manifest, but the user did not select that file.
  fileNotSelected,

  /// Manifest says encrypted, but this row has no salt or no IV, so there is
  /// nothing to derive a key with.
  missingCryptoParams,

  /// Decrypted (or read, when unencrypted) to something that is not a maFile.
  /// With the right passkey this means a corrupt file; across *every* entry it
  /// means the passkey was wrong.
  notReadable,
}

/// One account's outcome. Exactly one of [plaintext] / [problem] is set.
class SdaEntryResult {
  const SdaEntryResult.ok(this.entry, this.plaintext) : problem = null;
  const SdaEntryResult.failed(this.entry, this.problem) : plaintext = null;

  final SdaManifestEntry entry;
  final String? plaintext;
  final SdaEntryProblem? problem;

  bool get ok => plaintext != null;
}

/// The result of reading a whole selection.
class SdaImportResult {
  const SdaImportResult({
    required this.results,
    required this.wrongPassKey,
    required this.unlistedFiles,
  });

  final List<SdaEntryResult> results;

  /// Every encrypted entry failed to produce a readable maFile. One corrupt
  /// file is possible; all of them at once is a wrong passkey, and saying so
  /// is the difference between a user retrying and a user giving up.
  final bool wrongPassKey;

  /// Files the user selected that the manifest never mentions. Not an error —
  /// worth reporting so a mis-selected folder does not look like success.
  final List<String> unlistedFiles;

  Iterable<SdaEntryResult> get imported => results.where((r) => r.ok);
  Iterable<SdaEntryResult> get failed => results.where((r) => !r.ok);
}

/// Case-insensitive basename lookup. Users pick files through a system picker
/// whose reported names can differ in case from the manifest (and Windows,
/// where SDA runs, is case-insensitive to begin with).
String _key(String filename) =>
    filename.split(RegExp(r'[/\\]')).last.toLowerCase();

/// True when [text] parses as a JSON object — the check that separates a
/// correct passkey from a wrong one. AES-CBC with the wrong key usually fails
/// PKCS7 unpadding, but roughly 1 in 256 wrong keys produces valid-looking
/// padding and returns garbage, so padding alone is not a decision.
bool looksLikeMaFile(String text) {
  try {
    return jsonDecode(text) is Map;
  } catch (_) {
    return false;
  }
}

/// Reads a selected SDA bundle.
///
/// [files] maps the *basename* of each selected file to its contents;
/// `manifest.json` itself may be present and is ignored. [passKey] is required
/// when [manifest] is encrypted and ignored otherwise. Without a manifest,
/// selected .maFile files are read as plaintext; unrelated files are skipped.
Future<SdaImportResult> readSdaBundle({
  SdaManifest? manifest,
  required Map<String, String> files,
  String? passKey,
}) async {
  manifest ??= SdaManifest(
    encrypted: false,
    entries: [
      for (final name in files.keys)
        if (_key(name).endsWith('.mafile'))
          SdaManifestEntry(filename: name, steamId: 0),
    ],
  );
  final byName = {for (final e in files.entries) _key(e.key): e.value};
  final results = <SdaEntryResult>[];

  // Pass 1: pair rows with files and split out everything that cannot even be
  // attempted, so the decrypt batch only carries real work.
  final pending = <(SdaManifestEntry, String)>[];
  for (final entry in manifest.entries) {
    final contents = byName[_key(entry.filename)];
    if (contents == null) {
      results.add(
          SdaEntryResult.failed(entry, SdaEntryProblem.fileNotSelected));
      continue;
    }
    if (manifest.encrypted && !entry.hasCryptoParams) {
      results.add(
          SdaEntryResult.failed(entry, SdaEntryProblem.missingCryptoParams));
      continue;
    }
    pending.add((entry, contents));
  }

  var attemptedDecrypt = 0;
  var readable = 0;
  if (manifest.encrypted) {
    // One batch: 50000 PBKDF2 rounds per account, off the UI isolate.
    final plaintexts = await MaFileCrypto.decryptBatch(
      passKey ?? '',
      [for (final (e, ct) in pending) (e.salt!, e.iv!, ct)],
    );
    for (var i = 0; i < pending.length; i++) {
      final (entry, _) = pending[i];
      attemptedDecrypt++;
      final text = plaintexts[i];
      if (text == null || !looksLikeMaFile(text)) {
        results.add(SdaEntryResult.failed(entry, SdaEntryProblem.notReadable));
        continue;
      }
      readable++;
      results.add(SdaEntryResult.ok(entry, text));
    }
  } else {
    for (final (entry, contents) in pending) {
      if (!looksLikeMaFile(contents)) {
        results.add(SdaEntryResult.failed(entry, SdaEntryProblem.notReadable));
        continue;
      }
      results.add(SdaEntryResult.ok(entry, contents));
    }
  }

  final listed = {for (final e in manifest.entries) _key(e.filename)};
  final unlisted = [
    for (final name in files.keys)
      if (_key(name) != 'manifest.json' && !listed.contains(_key(name))) name,
  ];

  return SdaImportResult(
    results: results,
    // Only claim "wrong passkey" when decryption was actually attempted and
    // nothing came back readable. A bundle whose files were all missing must
    // not be reported as a bad password.
    wrongPassKey:
        manifest.encrypted && attemptedDecrypt > 0 && readable == 0,
    unlistedFiles: unlisted,
  );
}
