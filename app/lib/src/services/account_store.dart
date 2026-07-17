import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/crypto/ma_file_crypto.dart';
import '../core/crypto/vault_crypto.dart';
import '../core/ma_file_normalizer.dart';
import '../core/models/manifest.dart';
import '../core/models/steam_guard_account.dart';
import 'debug_log.dart';
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

  /// Serializes all mutating operations. Concurrent writers (refreshSessions,
  /// refreshAvatars, persistAccount, the unawaited vault migration) otherwise
  /// interleave check-then-act sequences over the shared manifest — see the
  /// alt-slot double-delete. Non-reentrant: public mutators acquire it and
  /// delegate to *Unlocked internals; internals never call locked wrappers.
  Future<void> _writeLock = Future<void>.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final run = _writeLock.then((_) => action());
    _writeLock = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

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

  Future<void> save() => _locked(_saveUnlocked);

  Future<void> _saveUnlocked() async {
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
    var decodedAny = false;
    var failed = 0;
    for (final text in texts) {
      if (text == null) {
        failed++; // corrupt blob OR wrong key — decided below
        continue;
      }
      try {
        accounts.add(SteamGuardAccount.fromJson(
            jsonDecode(text) as Map<String, dynamic>));
        decodedAny = true;
      } catch (_) {
        failed++;
      }
    }
    // "Empty == wrong key" is a contract callers rely on, but only when the
    // key genuinely can't open anything. If at least one entry decrypted, the
    // rest are individually corrupt — keep the good accounts instead of hiding
    // them all (a single bad maFile used to blank the whole list). For the
    // vault the DEK was already validated by its wrapper, so a null is always
    // corruption, never a wrong key; return whatever decoded.
    if (failed > 0) dlog('getAllAccounts: $failed/${entries.length} unreadable');
    if (entries.isNotEmpty && !decodedAny && !manifest.vault) {
      return const []; // no entry opened with this key → treat as wrong key
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
          {String? passKey}) =>
      _locked(() => _saveAccountUnlocked(account, encrypt, passKey: passKey));

  Future<bool> _saveAccountUnlocked(SteamGuardAccount account, bool encrypt,
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

    final idx =
        manifest.entries.indexWhere((e) => e.steamId == account.steamId);
    final oldEntry = idx >= 0 ? manifest.entries[idx] : null;

    // Encrypted UPDATE of an existing account: write the new ciphertext under a
    // *fresh* filename so the manifest (carrying the matching salt/iv) is the
    // single atomic commit point. Overwriting in place would let a crash leave
    // the manifest's salt/iv describing a different file's ciphertext — the
    // account then can't be decrypted (the legacy corruption window). New
    // accounts and the unencrypted path have no salt/iv to desync, so they
    // keep the canonical name.
    final filename = (encrypt && oldEntry != null)
        ? _altSlot(oldEntry.filename, account.steamId)
        : (oldEntry?.filename ?? '${account.steamId}.maFile');
    final newEntry = ManifestEntry(
      steamId: account.steamId,
      iv: iv,
      salt: salt,
      filename: filename,
    );
    if (idx >= 0) {
      manifest.entries[idx] = newEntry;
    } else {
      manifest.entries.add(newEntry);
    }

    final wasEncrypted = manifest.encrypted;
    manifest.encrypted = encrypt || manifest.encrypted;
    try {
      // Payload before manifest (both atomic): a crash in between leaves the
      // manifest pointing at the previous (valid) file — for an update that's
      // the untouched old file, for a new account an orphan payload recompute
      // ignores. save() is the commit point.
      await storage.writeFile(filename, jsonAccount);
      await _saveUnlocked();
      // The old ciphertext is now orphaned (manifest points at the new file).
      // Re-check after the awaits: only delete a file the manifest no longer
      // references (a concurrent/queued writer may have re-pointed it).
      if (oldEntry != null &&
          oldEntry.filename != filename &&
          !manifest.entries.any((e) => e.filename == oldEntry.filename)) {
        try {
          await storage.deleteFile(oldEntry.filename);
        } catch (_) {}
      }
      return true;
    } catch (_) {
      // Restore in-memory state to match what's still on disk.
      manifest.encrypted = wasEncrypted;
      if (oldEntry != null) {
        manifest.entries[idx] = oldEntry;
      } else {
        manifest.entries.removeWhere((e) => e.steamId == account.steamId);
      }
      return false;
    }
  }

  Future<bool> removeAccount(SteamGuardAccount account,
          {bool deleteMaFile = true}) =>
      _locked(() => _removeAccountUnlocked(account, deleteMaFile: deleteMaFile));

  Future<bool> _removeAccountUnlocked(SteamGuardAccount account,
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
    await _saveUnlocked();
    if (deleteMaFile) {
      try {
        await storage.deleteFile(entry.filename);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Removes the manifest entry (and its maFile) for [steamId], if present.
  /// Used to drop a code-only account's synthetic-id placeholder once its real
  /// SteamID is known after sign-in.
  Future<void> removeEntryById(int steamId) =>
      _locked(() => _removeEntryByIdUnlocked(steamId));

  Future<void> _removeEntryByIdUnlocked(int steamId) async {
    final idx = manifest.entries.indexWhere((e) => e.steamId == steamId);
    if (idx < 0) return;
    final entry = manifest.entries.removeAt(idx);
    await _saveUnlocked();
    try {
      await storage.deleteFile(entry.filename);
    } catch (_) {}
  }

  /// The alternate filename slot for [steamId], used to write an updated
  /// ciphertext without overwriting the one the current manifest still points
  /// at (two-phase commit). Toggles between `<id>.maFile` and `<id>.b.maFile`.
  String _altSlot(String current, int steamId) {
    final a = '$steamId.maFile';
    return current == a ? '$steamId.b.maFile' : a;
  }

  /// Re-encrypts every maFile with [newKey] (or decrypts when [newKey] is null).
  ///
  /// Two-phase: every account is re-written to a *fresh* filename first, then
  /// the manifest (new filenames + salt/iv + iteration count) is committed in
  /// one atomic save; only afterwards are the old ciphertexts deleted. Until
  /// that save lands the old files and old manifest stay fully consistent, so a
  /// crash mid-rotation leaves the store openable with the old key rather than
  /// a half-rotated, partly-undecryptable mess.
  ///
  /// Storage exceptions propagate (callers treat a mid-rotation throw as a
  /// crash); [_locked] must not swallow them.
  Future<bool> changeEncryptionKey(String? oldKey, String? newKey) =>
      _locked(() => _changeEncryptionKeyUnlocked(oldKey, newKey));

  Future<bool> _changeEncryptionKeyUnlocked(
      String? oldKey, String? newKey) async {
    if (manifest.encrypted) {
      if (oldKey == null || !await verifyPasskey(oldKey)) return false;
    }
    final oldIterations = manifest.kdfIterations;
    final toEncrypt = newKey != null;
    final newIterations = toEncrypt ? avaIterations : oldIterations;

    // Phase 1: write every re-keyed payload to a new filename. No manifest
    // mutation yet, so a failure/return here leaves the store untouched.
    final oldFiles = <String>[];
    final rewritten =
        <int, ({String filename, String? salt, String? iv})>{};
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
      final newName = _altSlot(entry.filename, entry.steamId);
      await storage.writeFile(newName, toWrite);
      oldFiles.add(entry.filename);
      rewritten[entry.steamId] =
          (filename: newName, salt: newSalt, iv: newIv);
    }

    // Phase 2 (commit): point every entry at its new file + params, save once.
    for (final entry in manifest.entries) {
      final r = rewritten[entry.steamId];
      if (r == null) continue;
      entry.filename = r.filename;
      entry.salt = r.salt;
      entry.iv = r.iv;
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
    await _saveUnlocked(); // commit point — new files are now the source of truth
    // Delete the old ciphertexts the manifest no longer references. A leftover
    // is harmless (recompute ignores unreferenced files); never delete a name
    // a rewrite reused.
    final live = rewritten.values.map((r) => r.filename).toSet();
    for (final f in oldFiles) {
      if (live.contains(f)) continue;
      try {
        await storage.deleteFile(f);
      } catch (_) {}
    }
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
      // Payload before manifest (see saveAccount) so a crash can't leave the
      // manifest referencing an unwritten or stale vault blob.
      await storage.writeFile(filename, blob);
      await _saveUnlocked();
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
  Future<void> migrateToVault(Uint8List dek, List<SteamGuardAccount> accounts) =>
      _locked(() => _migrateToVaultUnlocked(dek, accounts));

  Future<void> _migrateToVaultUnlocked(
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
    // Preserve entries that did not decrypt (accounts contains only the
    // successfully-decrypted set): keep them verbatim — filename + salt/iv —
    // so the ciphertext stays reachable for later recovery/export instead of
    // becoming an invisible orphan. Vault reads skip them (GCM decrypt fails
    // per-entry); _recomputeExistingEntries keeps them (file still exists).
    final migratedIds = {for (final e in newEntries) e.steamId};
    final preserved = manifest.entries
        .where((e) => !migratedIds.contains(e.steamId))
        .toList();
    if (preserved.isNotEmpty) {
      dlog('migrateToVault: preserving ${preserved.length} '
          'undecrypted entr${preserved.length == 1 ? 'y' : 'ies'}');
    }
    // Atomic commit: swap the manifest to the vault scheme + new filenames.
    manifest.entries = [...newEntries, ...preserved];
    manifest.vault = true;
    manifest.encrypted = true;
    manifest.schemaVersion = 2;
    manifest.passkeyCheck = null;
    _dek = dek;
    await _saveUnlocked();
    // Post-commit cleanup of the old CBC files (best-effort).
    for (final f in oldFilenames) {
      if (f.endsWith('.v2.maFile')) continue;
      try {
        await storage.deleteFile(f);
      } catch (_) {}
    }
  }

  /// Rebuilds a vault manifest by scanning the payload files on disk. Recovery
  /// path for a vault store whose manifest.json is lost: vault entries carry no
  /// per-entry crypto params (the DEK lives in the keystore), so the
  /// `<steamId>[.v2].maFile` filenames alone reconstitute them. Files whose
  /// prefix isn't a SteamID are skipped; a file that later fails GCM decrypt is
  /// skipped per-entry by [getAllAccounts], same as any corrupt vault blob.
  /// Callers gate this on evidence the store really was a vault (the keystore
  /// wrap record exists) — legacy CBC stores are unrebuildable, their salt/iv
  /// lived only in the manifest.
  static Future<void> rebuildVaultManifest(StorageProvider storage) async {
    final candidates = <int, List<String>>{};
    for (final name in await storage.listFiles()) {
      final dot = name.indexOf('.');
      if (dot <= 0) continue;
      final id = int.tryParse(name.substring(0, dot));
      if (id == null) continue;
      (candidates[id] ??= []).add(name);
    }
    // Per steamId, the most recently written file is the live payload: slot
    // deletes are best-effort, so a failed cleanup (e.g. a `.v2` blob left
    // behind after remove-then-relink re-created the bare name) leaves a
    // stale slot that a fixed rank order would resurrect over the real data.
    // Only when mtimes are unavailable or equal does [_slotRank] decide.
    final byId = <int, String>{};
    for (final e in candidates.entries) {
      var best = e.value.first;
      var bestTime = await storage.lastModified(best);
      for (final name in e.value.skip(1)) {
        final time = await storage.lastModified(name);
        final bool newer;
        if (time != null && bestTime != null) {
          // Equal (non-null) timestamps only arise when both slots were
          // written within the same clock tick — a remove-then-relink race,
          // where the re-created canonical bare name is the fresh payload.
          // The migration-era rank (.v2 first) is kept for the unknowable
          // null-mtime case only.
          newer = time.isAtSameMomentAs(bestTime)
              ? _tieRank(name) < _tieRank(best)
              : time.isAfter(bestTime);
        } else {
          newer = _slotRank(name) < _slotRank(best);
        }
        if (newer) {
          best = name;
          bestTime = time;
        }
      }
      byId[e.key] = best;
    }
    final manifest = Manifest(
      vault: true,
      encrypted: true,
      schemaVersion: 2,
      entries: [
        for (final e in byId.entries)
          ManifestEntry(steamId: e.key, filename: e.value),
      ],
    );
    await AccountStore(storage, manifest).save();
  }

  /// Tie-breaker when write times can't order a steamId's payload files: the
  /// migrated `.v2.maFile` beats the canonical `<id>.maFile`, which beats a
  /// leftover `.b.maFile` alt slot.
  static int _slotRank(String name) => name.endsWith('.v2.maFile')
      ? 0
      : name.endsWith('.b.maFile')
          ? 2
          : 1;

  /// Equal-timestamp tie-breaker: both slots written in the same clock tick
  /// implies remove-then-relink re-created the canonical bare name last, so
  /// it outranks a leftover `.v2.maFile` whose delete failed.
  static int _tieRank(String name) => name.endsWith('.v2.maFile')
      ? 1
      : name.endsWith('.b.maFile')
          ? 2
          : 0;

  /// PBKDF2 rounds for the legacy PIN-derived CBC scheme. Only reached now when
  /// rotating the key on an un-migrated legacy store; such stores upgrade to the
  /// Keystore-held DEK vault ([migrateToVault]) on their next unlock, after
  /// which the PIN no longer derives any file key.
  static const int avaIterations = 100;

  /// Moves the entry for [steamId] so it sits just before [beforeSteamId]'s
  /// entry (or last when null). Keyed by steamId, never by index: the UI list
  /// is the decryptable subset while `manifest.entries` keeps undecryptable
  /// entries too (kept-good-subset reads, entries preserved by
  /// [migrateToVault]), so UI indices don't address the manifest. Only the
  /// moved entry is touched — every other entry, undecryptable ones included,
  /// keeps its relative order. Does not save; callers commit via [save].
  Future<void> moveEntryById(int steamId, {int? beforeSteamId}) =>
      _locked(() async {
        final from =
            manifest.entries.indexWhere((e) => e.steamId == steamId);
        if (from < 0) return;
        final entry = manifest.entries.removeAt(from);
        final to = beforeSteamId == null
            ? -1
            : manifest.entries.indexWhere((e) => e.steamId == beforeSteamId);
        manifest.entries.insert(to < 0 ? manifest.entries.length : to, entry);
      });

  /// Parses and normalizes raw maFile JSON into the account it would import,
  /// resolving the effective SteamID (real, recovered, or synthetic) without
  /// writing anything. Throws [MaFileImportException] on unusable input.
  SteamGuardAccount parseMaFileContents(String contents, {String? sourceName}) {
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    final account = SteamGuardAccount.fromJson(
        MaFileNormalizer.normalize(decoded, sourceName: sourceName));
    if (account.steamId == 0) {
      // Some exports (Steam++ / Watt Toolkit) drop the Session block entirely,
      // so there is no SteamID. The shared_secret still generates valid 2FA
      // codes, so import it as a code-only account under a stable synthetic
      // key; signing in later (to use market / confirmations) fills in the
      // real SteamID and re-keys it.
      if ((account.sharedSecret ?? '').trim().isEmpty) {
        throw const MaFileImportException('maFile has no SteamID or secret');
      }
      account.session.steamId = syntheticSteamId(account);
    }
    return account;
  }

  /// Imports an existing `*.maFile` (its raw JSON text, already decrypted).
  /// Returns the imported account, encrypting it under the store's current
  /// passkey when the store is encrypted. When [mergeExisting] is the stored
  /// account this import overwrites, [mergeImportedAccount]'s policy keeps
  /// AVA-local enrichment the file doesn't carry.
  Future<SteamGuardAccount> importMaFileContents(
      String contents, String? passKey,
      {String? sourceName, SteamGuardAccount? mergeExisting}) async {
    final account = parseMaFileContents(contents, sourceName: sourceName);
    if (mergeExisting != null && mergeExisting.steamId == account.steamId) {
      mergeImportedAccount(account, mergeExisting);
    }
    final ok = await saveAccount(account, manifest.encrypted, passKey: passKey);
    if (!ok) throw const MaFileImportException('Failed to save imported file');
    return account;
  }

  /// A stable, negative synthetic id for a code-only account (no real SteamID).
  /// Negative so it can never collide with a real SteamID64 (always positive);
  /// derived deterministically from the shared secret so re-importing the same
  /// account overwrites rather than duplicates. Marked [visibleForTesting] so
  /// tests can assert the code-only path without hard-coding the value.
  @visibleForTesting
  static int syntheticSteamId(SteamGuardAccount a) {
    final seed = (a.sharedSecret ?? a.accountName ?? '').trim();
    // FNV-1a (32-bit), stable across runs unlike String.hashCode.
    var h = 0x811c9dc5;
    for (final c in seed.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return -(h & 0x7fffffff) - 1; // [-2^31 .. -1]
  }
}

/// Applies overwrite-merge policy: the imported file wins for authenticator
/// material; AVA-local enrichment and a live session survive when the file
/// doesn't carry its own.
@visibleForTesting
void mergeImportedAccount(
    SteamGuardAccount incoming, SteamGuardAccount existing) {
  incoming.avatarUrl ??= existing.avatarUrl;
  incoming.avatarFrameUrl ??= existing.avatarFrameUrl;
  incoming.animatedAvatarUrl ??= existing.animatedAvatarUrl;
  incoming.personaName ??= existing.personaName;
  if ((incoming.password ?? '').isEmpty) incoming.password = existing.password;
  // A stale backup must not kill a working login: keep the stored session
  // when the file brings no tokens of its own.
  if (!incoming.session.hasTokens && existing.session.hasTokens) {
    incoming.session = existing.session;
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
