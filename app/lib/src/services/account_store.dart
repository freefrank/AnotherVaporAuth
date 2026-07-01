import 'dart:convert';
import 'dart:typed_data';

import '../core/crypto/ma_file_crypto.dart';
import '../core/crypto/vault_crypto.dart';
import '../core/models/manifest.dart';
import '../core/models/steam_guard_account.dart';
import 'storage_provider.dart';

/// Manages the `maFiles/` directory: the manifest plus the per-account
/// `*.maFile` payloads. Faithful port of the business logic in the legacy C#
/// `Manifest` class, but with file IO delegated to a [StorageProvider].
class AccountStore {
  final StorageProvider storage;
  Manifest manifest;

  /// The in-memory Data Encryption Key for the vault scheme, set at unlock via
  /// [setDek]. Null until unlocked (or in legacy stores).
  Uint8List? _dek;

  AccountStore(this.storage, [Manifest? manifest])
      : manifest = manifest ?? Manifest();

  bool get encrypted => manifest.encrypted;
  bool get isVault => manifest.vault;
  List<ManifestEntry> get entries => manifest.entries;

  /// Provides (or clears) the vault DEK for the current unlocked session.
  void setDek(Uint8List? dek) => _dek = dek;

  /// Loads the manifest from disk, creating a fresh one if none exists.
  /// Drops entries whose maFile is missing (RecomputeExistingEntries).
  static Future<AccountStore> load(StorageProvider storage) async {
    if (!await storage.dirExists()) {
      final store = AccountStore(storage, Manifest());
      await store.save();
      return store;
    }
    final manifestFile = await storage.fileExists('manifest.json');
    if (!manifestFile) {
      throw const ManifestParseException();
    }
    try {
      final contents = await storage.readFile('manifest.json');
      final manifest =
          Manifest.fromJson(jsonDecode(contents) as Map<String, dynamic>);
      final store = AccountStore(storage, manifest);
      if (manifest.encrypted &&
          !manifest.vault &&
          manifest.entries.isEmpty &&
          manifest.passkeyCheck == null) {
        manifest.encrypted = false;
        await store.save();
      }
      await store._recomputeExistingEntries();
      return store;
    } catch (e) {
      if (e is ManifestParseException) rethrow;
      throw const ManifestParseException();
    }
  }

  Future<void> _recomputeExistingEntries() async {
    final kept = <ManifestEntry>[];
    for (final entry in manifest.entries) {
      if (await storage.fileExists(entry.filename)) kept.add(entry);
    }
    manifest.entries = kept;
    if (!manifest.vault &&
        manifest.entries.isEmpty &&
        manifest.passkeyCheck == null) {
      manifest.encrypted = false;
    }
  }

  Future<void> save() async {
    await storage.ensureDir();
    await storage.writeFile('manifest.json', jsonEncode(manifest.toJson()));
  }

  /// Decrypts and returns all accounts. Returns empty on bad passkey, matching
  /// the C# contract used by [verifyPasskey].
  Future<List<SteamGuardAccount>> getAllAccounts(
      {String? passKey, int limit = -1}) async {
    if (manifest.vault && _dek == null) return const [];
    if (passKey == null && manifest.encrypted && !manifest.vault) {
      return const [];
    }
    final entries =
        limit == -1 ? manifest.entries : manifest.entries.take(limit).toList();
    // Read raw payloads (IO), then decrypt them all in one background isolate.
    final raws = <String>[];
    for (final e in entries) {
      raws.add(await storage.readFile(e.filename));
    }
    List<String?> texts;
    if (manifest.vault) {
      texts = [for (final raw in raws) VaultCrypto.decryptPayload(_dek!, raw)];
    } else if (manifest.encrypted) {
      final items = [
        for (var i = 0; i < entries.length; i++)
          (entries[i].salt!, entries[i].iv!, raws[i])
      ];
      texts = await MaFileCrypto.decryptBatch(passKey!, items,
          iterations: manifest.kdfIterations);
    } else {
      texts = raws;
    }
    final accounts = <SteamGuardAccount>[];
    for (final text in texts) {
      if (text == null) return const []; // wrong key
      try {
        accounts.add(SteamGuardAccount.fromJson(
            jsonDecode(text) as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return accounts;
  }

  Future<bool> verifyPasskey(String passkey) async {
    if (!manifest.encrypted) return true;
    // Prefer the verification token (works with zero accounts).
    final check = manifest.passkeyCheck;
    if (check != null) {
      final parts = check.split('|');
      if (parts.length == 3) {
        final dec = (await MaFileCrypto.decryptBatch(
          passkey,
          [(parts[0], parts[1], parts[2])],
          iterations: manifest.kdfIterations,
        ))
            .first;
        return dec == _checkPlaintext;
      }
    }
    if (manifest.entries.isEmpty) return true;
    final accounts = await getAllAccounts(passKey: passkey, limit: 1);
    return accounts.length == 1;
  }

  /// Saves (or updates) an account, optionally encrypting with [passKey].
  Future<bool> saveAccount(SteamGuardAccount account, bool encrypt,
      {String? passKey}) async {
    // Vault mode: always encrypt with the in-memory DEK; the encrypt/passKey
    // args are legacy no-ops here.
    if (manifest.vault) {
      if (_dek == null) return false;
      return _saveVault(account);
    }
    if (encrypt && (passKey == null || passKey.isEmpty)) return false;
    if (!encrypt && manifest.encrypted) return false;

    String? salt;
    String? iv;
    var jsonAccount = jsonEncode(account.toJson());

    if (encrypt) {
      salt = MaFileCrypto.getRandomSalt();
      iv = MaFileCrypto.getInitializationVector();
      jsonAccount = MaFileCrypto.encrypt(passKey!, salt, iv, jsonAccount,
          iterations: manifest.kdfIterations);
    }

    final filename = '${account.steamId}.maFile';
    final newEntry = ManifestEntry(
      steamId: account.steamId,
      iv: iv,
      salt: salt,
      filename: filename,
    );

    final idx =
        manifest.entries.indexWhere((e) => e.steamId == account.steamId);
    if (idx >= 0) {
      manifest.entries[idx] = newEntry;
    } else {
      manifest.entries.add(newEntry);
    }

    final wasEncrypted = manifest.encrypted;
    manifest.encrypted = encrypt || manifest.encrypted;
    try {
      await save();
      await storage.writeFile(filename, jsonAccount);
      return true;
    } catch (_) {
      manifest.encrypted = wasEncrypted;
      return false;
    }
  }

  Future<bool> removeAccount(SteamGuardAccount account,
      {bool deleteMaFile = true}) async {
    final idx =
        manifest.entries.indexWhere((e) => e.steamId == account.steamId);
    if (idx < 0) return true;
    final entry = manifest.entries.removeAt(idx);
    if (!manifest.vault &&
        manifest.entries.isEmpty &&
        manifest.passkeyCheck == null) {
      manifest.encrypted = false;
    }
    await save();
    if (deleteMaFile) {
      try {
        await storage.deleteFile(entry.filename);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Re-encrypts every maFile with [newKey] (or decrypts when [newKey] is null).
  Future<bool> changeEncryptionKey(String? oldKey, String? newKey) async {
    if (manifest.encrypted) {
      if (oldKey == null || !await verifyPasskey(oldKey)) return false;
    }
    final oldIterations = manifest.kdfIterations;
    final toEncrypt = newKey != null;
    final newIterations = toEncrypt ? avaIterations : oldIterations;
    for (final entry in manifest.entries) {
      if (!await storage.fileExists(entry.filename)) continue;
      var contents = await storage.readFile(entry.filename);
      if (manifest.encrypted) {
        final dec = MaFileCrypto.decrypt(oldKey!, entry.salt!, entry.iv!,
            contents, iterations: oldIterations);
        if (dec == null) return false;
        contents = dec;
      }
      String? newSalt;
      String? newIv;
      var toWrite = contents;
      if (toEncrypt) {
        newSalt = MaFileCrypto.getRandomSalt();
        newIv = MaFileCrypto.getInitializationVector();
        toWrite = MaFileCrypto.encrypt(newKey, newSalt, newIv, contents,
            iterations: newIterations);
      }
      await storage.writeFile(entry.filename, toWrite);
      entry.iv = newIv;
      entry.salt = newSalt;
    }
    manifest.encrypted = toEncrypt;
    manifest.kdfIterations = newIterations;
    if (toEncrypt) {
      // Store a passkey-verification token so the PIN can be checked even with
      // no accounts.
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      final ct = MaFileCrypto.encrypt(newKey, salt, iv, _checkPlaintext,
          iterations: newIterations);
      manifest.passkeyCheck = '$salt|$iv|$ct';
    } else {
      manifest.passkeyCheck = null;
    }
    await save();
    return true;
  }

  static const String _checkPlaintext = 'AVA-PASSKEY-CHECK';

  /// Writes one account as a vault (AES-GCM) blob under the in-memory DEK,
  /// reusing its existing filename so migrated `.v2.maFile` names stay stable.
  Future<bool> _saveVault(SteamGuardAccount account) async {
    final blob =
        VaultCrypto.encryptPayload(_dek!, jsonEncode(account.toJson()));
    final idx =
        manifest.entries.indexWhere((e) => e.steamId == account.steamId);
    final filename =
        idx >= 0 ? manifest.entries[idx].filename : '${account.steamId}.maFile';
    final entry = ManifestEntry(steamId: account.steamId, filename: filename);
    if (idx >= 0) {
      manifest.entries[idx] = entry;
    } else {
      manifest.entries.add(entry);
    }
    try {
      await save();
      await storage.writeFile(filename, blob);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Migrates a legacy (PIN/CBC) store to the vault scheme in place, using the
  /// caller-supplied random [dek] and the already-decrypted [accounts] from the
  /// just-completed legacy unlock.
  ///
  /// Crash-safe: vault blobs are written to fresh `<steamId>.v2.maFile` files
  /// while the legacy `<steamId>.maFile` files stay intact, and the manifest —
  /// the single source of truth for which scheme/filenames to read — is written
  /// last in one atomic [save]. A crash before that leaves a fully readable
  /// legacy store (the `.v2` files are harmless orphans); a crash after leaves a
  /// fully readable vault store. Old files are deleted best-effort afterwards.
  Future<void> migrateToVault(
      Uint8List dek, List<SteamGuardAccount> accounts) async {
    if (manifest.vault) return;
    final oldFilenames = <String>[];
    final newEntries = <ManifestEntry>[];
    for (final acc in accounts) {
      final blob = VaultCrypto.encryptPayload(dek, jsonEncode(acc.toJson()));
      final newName = '${acc.steamId}.v2.maFile';
      await storage.writeFile(newName, blob);
      final oldIdx =
          manifest.entries.indexWhere((e) => e.steamId == acc.steamId);
      if (oldIdx >= 0) oldFilenames.add(manifest.entries[oldIdx].filename);
      newEntries.add(ManifestEntry(steamId: acc.steamId, filename: newName));
    }
    // Atomic commit: swap the manifest to the vault scheme + new filenames.
    manifest.entries = newEntries;
    manifest.vault = true;
    manifest.encrypted = true;
    manifest.schemaVersion = 2;
    manifest.passkeyCheck = null;
    _dek = dek;
    await save();
    // Post-commit cleanup of the old CBC files (best-effort).
    for (final f in oldFilenames) {
      if (f.endsWith('.v2.maFile')) continue;
      try {
        await storage.deleteFile(f);
      } catch (_) {}
    }
  }

  /// PBKDF2 rounds for the legacy PIN-derived CBC scheme. Only reached now when
  /// rotating the key on an un-migrated legacy store; such stores upgrade to the
  /// Keystore-held DEK vault ([migrateToVault]) on their next unlock, after
  /// which the PIN no longer derives any file key.
  static const int avaIterations = 100;

  void moveEntry(int from, int to) {
    if (from < 0 || to < 0 || from >= manifest.entries.length) return;
    if (to >= manifest.entries.length) to = manifest.entries.length - 1;
    final e = manifest.entries.removeAt(from);
    manifest.entries.insert(to, e);
  }

  /// Imports an existing `*.maFile` (its raw JSON text, already decrypted).
  /// Returns the imported account, encrypting it under the store's current
  /// passkey when the store is encrypted.
  Future<SteamGuardAccount> importMaFileContents(
      String contents, String? passKey) async {
    final account = SteamGuardAccount.fromJson(
        jsonDecode(contents) as Map<String, dynamic>);
    if (account.steamId == 0) {
      throw const MaFileImportException('maFile has no SteamID');
    }
    final ok = await saveAccount(account, manifest.encrypted, passKey: passKey);
    if (!ok) throw const MaFileImportException('Failed to save imported file');
    return account;
  }
}

class ManifestParseException implements Exception {
  const ManifestParseException();
  @override
  String toString() => 'ManifestParseException';
}

class MaFileImportException implements Exception {
  final String message;
  const MaFileImportException(this.message);
  @override
  String toString() => 'MaFileImportException: $message';
}
