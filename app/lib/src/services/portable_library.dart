import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/crypto/secure_random.dart';
import '../core/crypto/vault_crypto.dart';
import '../core/models/manifest.dart';
import '../core/models/steam_guard_account.dart';
import 'account_store.dart';
import 'storage_provider.dart';

/// Resolve the outer launcher, not the extracted Flutter executable.
String? portableDirectory({
  required String operatingSystem,
  required String executable,
  required Map<String, String> environment,
}) {
  if (!['windows', 'linux', 'macos'].contains(operatingSystem)) return null;
  final paths = operatingSystem == 'windows' ? p.windows : p.posix;
  final outer = environment['AVA_PORTABLE_ROOT'];
  if (outer != null && outer.isNotEmpty) {
    if (!paths.isAbsolute(outer)) {
      throw const FormatException('Portable path must be absolute');
    }
    return paths.join(outer, 'maFiles');
  }
  final appImage = environment['APPIMAGE'];
  if (operatingSystem == 'linux' &&
      appImage != null &&
      paths.isAbsolute(appImage)) {
    return paths.join(paths.dirname(appImage), 'maFiles');
  }
  var root = paths.dirname(executable);
  if (operatingSystem == 'macos') {
    final segments = paths.split(executable);
    final app = segments.indexWhere((part) => part.endsWith('.app'));
    if (app >= 0) root = paths.joinAll(segments.take(app));
  }
  return paths.join(root, 'maFiles');
}

const portableKdfIterations = 600000;
Map<String, dynamic> _wrap((String, Uint8List) input) {
  final salt = VaultCrypto.randomSaltB64();
  return {
    'v': 1,
    'salt': salt,
    'iterations': portableKdfIterations,
    'wrap': VaultCrypto.wrapDek(
      input.$1,
      salt,
      input.$2,
      iterations: portableKdfIterations,
    ),
  };
}

Uint8List? _unwrap((String, Map<String, dynamic>) input) {
  final key = input.$2;
  // Reject malformed/unbounded costs before spending CPU on untrusted media.
  if (key['v'] != 1 || key['iterations'] != portableKdfIterations) {
    throw const FormatException('Unsupported portable key');
  }
  return VaultCrypto.unwrapDek(
    input.$1,
    key['salt'] as String,
    key['wrap'] as String,
    iterations: portableKdfIterations,
  );
}

/// Independent removable library. No credentials or keys are written to the
/// host's credential manager. Manifest replacement is the commit point; payloads
/// always use fresh names so an interrupted write cannot damage a live account.
class PortableLibrary {
  PortableLibrary(this.storage);
  final StorageProvider storage;
  AccountStore? _store;
  Uint8List? _dek;
  String? _legacyPassword;
  String? _diskManifest;
  List<SteamGuardAccount> accounts = const [];
  Object? error;
  Future<void>? _queue;

  bool get enabled => _store?.manifest.portableEnabled ?? false;
  bool get configured => _store?.manifest.portableKey != null;
  bool get locked =>
      (_store?.encrypted ?? false) && _dek == null && _legacyPassword == null;
  bool get hasData => _store?.entries.isNotEmpty ?? false;
  bool get foreignVault => (_store?.isVault ?? false) && !configured;
  List<int> get ids => [
    for (final e in _store?.entries ?? <ManifestEntry>[]) e.steamId,
  ];

  Future<T> _serial<T>(Future<T> Function() run) {
    final result = _queue == null
        ? Future<T>.sync(run)
        : _queue!.then((_) => run());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Discovery never creates a folder or mutates a manifest, including SDA's.
  Future<void> discover() async {
    lock();
    _store = null;
    _diskManifest = null;
    accounts = const [];
    error = null;
    try {
      if (!await storage.dirExists()) return;
      Manifest manifest;
      if (await storage.fileExists('manifest.json')) {
        _diskManifest = await storage.readFile('manifest.json');
        manifest = Manifest.fromJson(
          jsonDecode(_diskManifest!) as Map<String, dynamic>,
        );
      } else {
        manifest = Manifest();
        final parser = AccountStore(storage, manifest);
        var encryptedOrphans = false;
        for (final name in await storage.listFiles(extension: '')) {
          if (name.startsWith('.portable.')) {
            encryptedOrphans = true;
            continue;
          }
          if (!name.toLowerCase().endsWith('.mafile')) continue;
          final account = parser.parseMaFileContents(
            await storage.readFile(name),
            sourceName: name,
          );
          if (manifest.entries.any((e) => e.steamId == account.steamId)) {
            throw const FormatException(
              'Duplicate accounts in adjacent maFiles',
            );
          }
          manifest.entries.add(
            ManifestEntry(filename: name, steamId: account.steamId),
          );
        }
        if (encryptedOrphans && manifest.entries.isEmpty) {
          throw const FormatException('Portable manifest is missing');
        }
      }
      _store = AccountStore(storage, manifest);
      if (!locked) await _readAll();
    } catch (e) {
      error = e;
      accounts = const [];
    }
  }

  Future<void> _readAll() async {
    final read = await _store!.getAllAccounts(passKey: _legacyPassword);
    if (read.length != _store!.entries.length) {
      throw const FormatException('Some portable accounts could not be read');
    }
    for (final account in read) {
      account.fromPortable = true;
    }
    accounts = List.unmodifiable(read);
  }

  Future<bool> unlock(String password) => _serial(() async {
    if (error != null || foreignVault || _store == null) return false;
    await _checkDisk();
    if (configured) {
      final key = await compute(_unwrap, (
        password,
        _store!.manifest.portableKey!,
      ));
      if (key == null) return false;
      _dek = key;
      _store!.setDek(key);
    } else if (_store!.encrypted) {
      if (!await _store!.verifyPasskey(password)) return false;
      _legacyPassword = password;
    }
    try {
      await _readAll();
      return true;
    } catch (_) {
      lock();
      rethrow;
    }
  });

  void lock() {
    _dek?.fillRange(0, _dek!.length, 0);
    _dek = null;
    _legacyPassword = null;
    _store?.setDek(null);
    if (_store?.encrypted ?? false) accounts = const [];
  }

  Future<void> _checkDisk() async {
    // A removed drive or another AVA instance must never cause a replacement
    // library to be silently created from a stale in-memory snapshot.
    if (_diskManifest != null) {
      if (!await storage.fileExists('manifest.json') ||
          await storage.readFile('manifest.json') != _diskManifest) {
        throw const FileSystemException(
          'Portable library changed or is unavailable',
        );
      }
    } else if (await storage.fileExists('manifest.json')) {
      throw const FileSystemException(
        'Portable library appeared; reopen it first',
      );
    }
  }

  Future<void> _commit(
    Manifest next,
    List<SteamGuardAccount> nextAccounts,
  ) async {
    await _checkDisk();
    final text = jsonEncode(next.toJson());
    await storage.writeFile('manifest.json', text);
    _diskManifest = text;
    _store = AccountStore(storage, next)..setDek(_dek);
    accounts = List.unmodifiable(
      nextAccounts.map(
        (a) => SteamGuardAccount.fromJson(a.toJson())..fromPortable = true,
      ),
    );
  }

  /// Establish the independent vault. Old AppData records are never touched.
  Future<void> configure(String password) => _serial(() async {
    if (password.length < 12) {
      throw const FormatException('Use at least 12 characters');
    }
    if (error != null || locked || configured) {
      throw StateError('Library is not ready');
    }
    await _checkDisk();
    final key = VaultCrypto.generateDek();
    final wrap = await compute(_wrap, (password, key));
    final next = Manifest(
      encrypted: true,
      vault: true,
      schemaVersion: 2,
      portableKey: wrap,
      portableEnabled: false,
    );
    await storage.ensureDir();
    for (final account in accounts) {
      final name = '.portable.${account.steamId}.${secureRandomHex(8)}.maFile';
      await storage.writeFile(
        name,
        VaultCrypto.encryptPayload(key, jsonEncode(account.toJson())),
      );
      next.entries.add(ManifestEntry(filename: name, steamId: account.steamId));
    }
    final oldEntries = [...?_store?.entries];
    _dek = key;
    try {
      await _commit(next, accounts);
    } catch (_) {
      _dek = null;
      key.fillRange(0, key.length, 0);
      rethrow;
    }
    // Only after the durable manifest (including the wrapped key) commits.
    // Keep failed cleanup visible: a leftover plaintext file is not encrypted.
    for (final entry in oldEntries) {
      await storage.deleteFile(entry.filename);
    }
  });

  Future<void> setEnabled(bool value) => _serial(() async {
    if (error != null || (value && (!configured || locked))) {
      throw StateError('Unlock the portable library first');
    }
    await _checkDisk();
    final next = Manifest.fromJson(_store!.manifest.toJson())
      ..portableEnabled = value;
    await _commit(next, accounts);
  });

  Future<void> save(SteamGuardAccount account) => _serial(() async {
    if (!configured || locked || error != null) {
      throw StateError('Unlock and configure the portable library first');
    }
    await _checkDisk();
    final next = Manifest.fromJson(_store!.manifest.toJson());
    final index = next.entries.indexWhere((e) => e.steamId == account.steamId);
    final name = '.portable.${account.steamId}.${secureRandomHex(8)}.maFile';
    final entry = ManifestEntry(filename: name, steamId: account.steamId);
    final oldName = index < 0 ? null : next.entries[index].filename;
    if (index < 0) {
      next.entries.add(entry);
    } else {
      next.entries[index] = entry;
    }
    final plaintext = jsonEncode(account.toJson());
    await storage.writeFile(name, VaultCrypto.encryptPayload(_dek!, plaintext));
    if (VaultCrypto.decryptPayload(_dek!, await storage.readFile(name)) !=
        plaintext) {
      throw const FileSystemException('Portable write verification failed');
    }
    final nextAccounts = [...accounts];
    final at = nextAccounts.indexWhere((a) => a.steamId == account.steamId);
    final copy = SteamGuardAccount.fromJson(account.toJson())
      ..fromPortable = true;
    if (at < 0) {
      nextAccounts.add(copy);
    } else {
      nextAccounts[at] = copy;
    }
    await _commit(next, nextAccounts);
    if (oldName != null) {
      try {
        await storage.deleteFile(oldName);
      } catch (_) {
        /* encrypted orphan */
      }
    }
  });

  Future<void> remove(int id) => _serial(() async {
    if (locked || error != null) throw StateError('Portable library is locked');
    await _checkDisk();
    final next = Manifest.fromJson(_store!.manifest.toJson());
    final removed = next.entries.where((e) => e.steamId == id).toList();
    next.entries.removeWhere((e) => e.steamId == id);
    await _commit(next, accounts.where((a) => a.steamId != id).toList());
    for (final entry in removed) {
      await storage.deleteFile(entry.filename);
    }
  });
}
