import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/vault_crypto.dart';

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
    final blob = VaultCrypto.wrapDek(pin, salt, dek);
    await _store.write(key: _kSalt, value: salt);
    await _store.write(key: _kWrapped, value: blob);
  }

  /// Returns the DEK if [pin] is correct, else null (wrong PIN / not set up).
  Future<Uint8List?> unwrapWithPin(String pin) async {
    try {
      final salt = await _store.read(key: _kSalt);
      final blob = await _store.read(key: _kWrapped);
      if (salt == null || blob == null) return null;
      return VaultCrypto.unwrapDek(pin, salt, blob);
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
    } catch (_) {}
  }
}
