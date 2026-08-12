/// The sync trash: every account payload that sync removes or overrides on
/// this device lands here first, encrypted, for 30 days. There is no path
/// through the sync feature where "picked the wrong side of a conflict" or
/// "another device deleted it" destroys the only copy of a secret.
///
/// Entries are encrypted with the sync passphrase (same SDA scheme as the
/// remote), NOT written in plaintext: the local store is vault-encrypted at
/// rest, and the trash must not be the one plaintext hole beside it. Restore
/// therefore asks for the passphrase when the stored one no longer opens an
/// entry (e.g. sync was reconfigured since) — same judgement as SDA import.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/crypto/ma_file_crypto.dart';
import '../storage_provider.dart';

/// Why an entry landed in the trash.
enum SyncTrashReason { remoteDelete, conflictLocal, conflictRemote }

class SyncTrashEntry {
  final String filename;
  final int steamId;
  final String? accountName;
  final DateTime deletedAt;
  final SyncTrashReason reason;
  final String salt;
  final String iv;
  final String ciphertext;

  const SyncTrashEntry({
    required this.filename,
    required this.steamId,
    required this.accountName,
    required this.deletedAt,
    required this.reason,
    required this.salt,
    required this.iv,
    required this.ciphertext,
  });

  /// Decrypts the stored payload; null on a wrong passphrase / corruption.
  Map<String, dynamic>? decrypt(String passphrase) {
    final text =
        MaFileCrypto.decrypt(passphrase, salt, iv, ciphertext);
    if (text == null) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class SyncTrash {
  final StorageProvider storage;
  final DateTime Function() now;

  static const Duration retention = Duration(days: 30);

  SyncTrash(this.storage, {DateTime Function()? now})
      : now = now ?? DateTime.now;

  Future<String> _dir() async =>
      p.join(p.dirname(await storage.maFilesDir()), 'sync_trash');

  /// Encrypts [payload] under [passphrase] and stores it. Never throws — a
  /// failed trash write must not abort the sync round that triggered it, but
  /// the caller is told (false) so it can refuse a destructive follow-up.
  Future<bool> put({
    required int steamId,
    required String? accountName,
    required Map<String, dynamic> payload,
    required SyncTrashReason reason,
    required String passphrase,
  }) async {
    try {
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      final ct =
          MaFileCrypto.encrypt(passphrase, salt, iv, jsonEncode(payload));
      final stamp = now().toUtc();
      final dir = await _dir();
      await Directory(dir).create(recursive: true);
      final name = '$steamId.${stamp.millisecondsSinceEpoch}.trash.json';
      await StorageProvider.replaceFileAtomic(
        p.join(dir, name),
        jsonEncode({
          'steam_id': steamId,
          'account_name': ?accountName,
          'deleted_at': stamp.toIso8601String(),
          'reason': reason.name,
          'salt': salt,
          'iv': iv,
          'ciphertext': ct,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<SyncTrashEntry>> list() async {
    final dir = Directory(await _dir());
    if (!await dir.exists()) return const [];
    final entries = <SyncTrashEntry>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.trash.json')) continue;
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is! Map<String, dynamic>) continue;
        entries.add(SyncTrashEntry(
          filename: p.basename(f.path),
          steamId: (json['steam_id'] as num?)?.toInt() ?? 0,
          accountName: json['account_name'] as String?,
          deletedAt:
              DateTime.tryParse((json['deleted_at'] as String?) ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
          reason: SyncTrashReason.values.firstWhere(
            (r) => r.name == json['reason'],
            orElse: () => SyncTrashReason.remoteDelete,
          ),
          salt: (json['salt'] as String?) ?? '',
          iv: (json['iv'] as String?) ?? '',
          ciphertext: (json['ciphertext'] as String?) ?? '',
        ));
      } catch (_) {/* skip unreadable entries */}
    }
    entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return entries;
  }

  Future<void> delete(String filename) async {
    try {
      final f = File(p.join(await _dir(), filename));
      if (await f.exists()) await f.delete();
    } catch (_) {/* best-effort */}
  }

  /// Removes entries past [retention]. Called on engine start.
  Future<void> purgeExpired() async {
    final cutoff = now().toUtc().subtract(retention);
    for (final e in await list()) {
      if (e.deletedAt.isBefore(cutoff)) await delete(e.filename);
    }
  }
}
