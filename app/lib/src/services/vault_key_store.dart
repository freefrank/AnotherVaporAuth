import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/vault_crypto.dart';

// Legacy 100k-round unwraps are still hundreds of ms — run wrap/unwrap in a
// background isolate so the unlock animation keeps playing. Top-level
// functions because `compute` requires a sendable entry point.
String _wrapJob((String pin, String salt, Uint8List dek, int iter) a) =>
    VaultCrypto.wrapDek(a.$1, a.$2, a.$3, iterations: a.$4);

Uint8List? _unwrapJob((String pin, String salt, String blob, int iter) a) =>
    VaultCrypto.unwrapDek(a.$1, a.$2, a.$3, iterations: a.$4);

typedef _Wrap = ({String salt, int iterations, String blob, bool legacy});

/// Holds the vault Data Encryption Key, PIN-wrapped, in Android Keystore-backed
/// secure storage. The wrapped blob and its salt are encrypted at rest by the
/// platform Keystore master key, so copies are useless off-device; the PIN is
/// still required to unwrap the DEK ([VaultCrypto.unwrapDek]).
///
/// Everything lives in ONE JSON record so an update is a single (atomic)
/// write — the DEK exists nowhere else, and the earlier three-key layout could
/// be torn by a crash mid-PIN-change, losing the vault permanently. The old
/// split keys are still read as a fallback and upgraded on the next unlock.
class VaultKeyStore {
  final FlutterSecureStorage _store;

  VaultKeyStore({FlutterSecureStorage? store})
      : _store = store ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kRecord = 'ava.vault.pinWrap';
  // Legacy split-key layout (pre-atomic-record installs).
  static const _kLegacyWrapped = 'ava.vault.wrappedDek';
  static const _kLegacySalt = 'ava.vault.pinSalt';
  static const _kLegacyIterations = 'ava.vault.pinKdfIter';
  // Installs from before the round count was recorded were always 100k.
  static const _legacyDefaultIterations = 100000;

  /// Whether a wrapped DEK is present (i.e. the vault has been set up).
  Future<bool> get exists async {
    try {
      return await _store.containsKey(key: _kRecord) ||
          await _store.containsKey(key: _kLegacyWrapped);
    } catch (_) {
      return false;
    }
  }

  /// Wraps [dek] with [pin] under a fresh salt and stores the record.
  /// Overwrites any existing wrap (used for setup and PIN change).
  Future<void> storePinWrap(String pin, Uint8List dek) async {
    final salt = VaultCrypto.randomSaltB64();
    const iterations = VaultCrypto.pinKdfIterations;
    final blob = await compute(_wrapJob, (pin, salt, dek, iterations));
    await _store.write(
      key: _kRecord,
      value: jsonEncode({
        'v': 1,
        'salt': salt,
        'iter': iterations,
        'wrap': blob,
      }),
    );
    // The record is now live; the split-key copies are stale. Best-effort
    // only: _readWrap prefers the record, so a failed delete is harmless and
    // must not turn an already-durable wrap into a reported error.
    try {
      await _deleteLegacy();
    } catch (_) {}
  }

  /// Returns the DEK if [pin] is correct, else null (wrong PIN / not set up).
  Future<Uint8List?> unwrapWithPin(String pin) async {
    try {
      final wrap = await _readWrap();
      if (wrap == null) return null;
      final dek = await compute(
          _unwrapJob, (pin, wrap.salt, wrap.blob, wrap.iterations));
      if (dek == null) return null;
      // Opportunistic upgrade: legacy layout or an out-of-date KDF cost gets
      // re-wrapped under the current parameters. Safe to fail — the write is
      // atomic and the existing wrap keeps opening until it succeeds.
      if (wrap.legacy || wrap.iterations != VaultCrypto.pinKdfIterations) {
        try {
          await storePinWrap(pin, dek);
        } catch (_) {}
      }
      return dek;
    } catch (_) {
      return null;
    }
  }

  /// Re-wraps the DEK under [newPin]. Returns false if [oldPin] is wrong.
  Future<bool> rewrapPin(String oldPin, String newPin) async {
    final dek = await unwrapWithPin(oldPin);
    if (dek == null) return false;
    await storePinWrap(newPin, dek);
    return true;
  }

  Future<void> clear() async {
    try {
      await _store.delete(key: _kRecord);
      await _deleteLegacy();
    } catch (_) {}
  }

  Future<_Wrap?> _readWrap() async {
    final raw = await _store.read(key: _kRecord);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return (
          salt: m['salt'] as String,
          iterations: m['iter'] as int,
          blob: m['wrap'] as String,
          legacy: false,
        );
      } catch (_) {
        // Corrupt/torn record (e.g. a migration write cut short). Fall through
        // to the legacy keys — they are only deleted AFTER a record write
        // succeeds, so they still hold a valid wrap in exactly this scenario,
        // and the next successful unlock rewrites the record (self-healing).
        // A corrupt record must never masquerade as "wrong PIN" while an
        // intact fallback exists.
      }
    }
    final salt = await _store.read(key: _kLegacySalt);
    final blob = await _store.read(key: _kLegacyWrapped);
    if (salt == null || blob == null) return null;
    final iterations =
        int.tryParse(await _store.read(key: _kLegacyIterations) ?? '') ??
            _legacyDefaultIterations;
    return (salt: salt, iterations: iterations, blob: blob, legacy: true);
  }

  Future<void> _deleteLegacy() async {
    await _store.delete(key: _kLegacyWrapped);
    await _store.delete(key: _kLegacySalt);
    await _store.delete(key: _kLegacyIterations);
  }
}
