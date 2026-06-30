import 'dart:convert';

import '../core/crypto/ma_file_crypto.dart';
import '../core/models/manifest.dart';
import '../core/models/steam_guard_account.dart';
import 'storage_provider.dart';

/// Manages the `maFiles/` directory: the manifest plus the per-account
/// `*.maFile` payloads. Faithful port of the business logic in the legacy C#
/// `Manifest` class, but with file IO delegated to a [StorageProvider].
class AccountStore {
  final StorageProvider storage;
  Manifest manifest;

  AccountStore(this.storage, [Manifest? manifest])
      : manifest = manifest ?? Manifest();

  bool get encrypted => manifest.encrypted;
  List<ManifestEntry> get entries => manifest.entries;

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
    if (manifest.entries.isEmpty && manifest.passkeyCheck == null) {
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
    if (passKey == null && manifest.encrypted) return const [];
    final entries =
        limit == -1 ? manifest.entries : manifest.entries.take(limit).toList();
    // Read raw payloads (IO), then decrypt them all in one background isolate.
    final raws = <String>[];
    for (final e in entries) {
      raws.add(await storage.readFile(e.filename));
    }
    List<String?> texts;
    if (manifest.encrypted) {
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
    if (manifest.entries.isEmpty && manifest.passkeyCheck == null) {
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

  /// Re-encrypts already-decrypted [accounts] at [avaIterations]. Migrates an
  /// old high-rounds store to the fast PIN scheme without re-deriving the slow
  /// key (the accounts are already in memory after unlock).
  Future<void> reencrypt(
      String passKey, List<SteamGuardAccount> accounts) async {
    if (!manifest.encrypted) return;
    manifest.kdfIterations = avaIterations;
    for (final acc in accounts) {
      await saveAccount(acc, true, passKey: passKey);
    }
    final salt = MaFileCrypto.getRandomSalt();
    final iv = MaFileCrypto.getInitializationVector();
    final ct = MaFileCrypto.encrypt(passKey, salt, iv, _checkPlaintext,
        iterations: avaIterations);
    manifest.passkeyCheck = '$salt|$iv|$ct';
    await save();
  }

  /// PBKDF2 rounds for AVA's own PIN encryption. Deliberately tiny: a 6-digit
  /// PIN has only ~1e6 combinations, so anyone with the files brute-forces it
  /// regardless of rounds — the real protection is on-device storage + the
  /// keystore-backed biometric. High rounds (pointycastle does ~10k/sec) would
  /// only make unlock slow for no real gain, so we keep them minimal.
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
