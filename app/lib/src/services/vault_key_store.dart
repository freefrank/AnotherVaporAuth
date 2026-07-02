import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/vault_crypto.dart';

// PBKDF2 at 100k iterations is still hundreds of ms — run the wrap/unwrap in
// a background isolate so the unlock animation keeps playing. Top-level
// functions because `compute` requires a sendable entry point.
String _wrapJob((String pin, String salt, Uint8List dek, int iter) a) =>
    VaultCrypto.wrapDek(a.$1, a.$2, a.$3, iterations: a.$4);

Uint8List? _unwrapJob((String pin, String salt, String blob, int iter) a) =>
    VaultCrypto.unwrapDek(a.$1, a.$2, a.$3, iterations: a.$4);

/// Holds the vault Data Encryption Key, PIN-wrapped, in Android Keystore-backed
/// secure storage. The wrapped blob and its salt are encrypted at rest by the
/// platform Keystore master key, so copies are useless off-device; the PIN is
/// still required to unwrap the DEK ([VaultCrypto.unwrapDek]).
class VaultKeyStore {
  final FlutterSecureStorage _store;

  VaultKeyStore({FlutterSecureStorage? store})
      : _store = store ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kWrapped = 'ava.vault.wrappedDek';
  static const _kSalt = 'ava.vault.pinSalt';
  // KDF rounds used for the stored wrap. Absent on installs from before it
  // was recorded — those were always written with 100k.
  static const _kIterations = 'ava.vault.pinKdfIter';
  static const _legacyIterations = 100000;

  /// Whether a wrapped DEK is present (i.e. the vault has been set up).
  Future<bool> get exists async {
    try {
      return await _store.containsKey(key: _kWrapped);
    } catch (_) {
      return false;
    }
  }

  /// Wraps [dek] with [pin] under a fresh salt and stores both. Overwrites any
  /// existing wrap (used for setup and PIN change).
  Future<void> storePinWrap(String pin, Uint8List dek) async {
    final salt = VaultCrypto.randomSaltB64();
    const iterations = VaultCrypto.pinKdfIterations;
    final blob = await compute(_wrapJob, (pin, salt, dek, iterations));
    await _store.write(key: _kSalt, value: salt);
    // Recorded so the constant can change later without breaking old wraps
    // (they re-wrap naturally on the next PIN change).
    await _store.write(key: _kIterations, value: '$iterations');
    await _store.write(key: _kWrapped, value: blob);
  }

  /// Returns the DEK if [pin] is correct, else null (wrong PIN / not set up).
  Future<Uint8List?> unwrapWithPin(String pin) async {
    try {
      final salt = await _store.read(key: _kSalt);
      final blob = await _store.read(key: _kWrapped);
      if (salt == null || blob == null) return null;
      final iterations = int.tryParse(
              await _store.read(key: _kIterations) ?? '') ??
          _legacyIterations;
      return await compute(_unwrapJob, (pin, salt, blob, iterations));
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
      await _store.delete(key: _kWrapped);
      await _store.delete(key: _kSalt);
      await _store.delete(key: _kIterations);
    } catch (_) {}
  }
}
