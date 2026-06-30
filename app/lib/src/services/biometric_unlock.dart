import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'debug_log.dart';

/// System-credential app unlock. The encryption passkey is kept in the platform
/// secure storage (Android Keystore-backed); the device's system authentication
/// (biometric OR PIN / pattern / password) gates retrieving it. Manual passkey
/// entry always remains as a fallback.
class BiometricUnlock {
  final LocalAuthentication _auth;
  final FlutterSecureStorage _store;

  BiometricUnlock({LocalAuthentication? auth, FlutterSecureStorage? store})
      : _auth = auth ?? LocalAuthentication(),
        _store = store ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'ava.unlock.passkey';

  /// Whether the device can perform a system unlock (biometric or device PIN).
  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Whether unlock is currently set up (a passkey is stored).
  Future<bool> get isEnabled async {
    try {
      return await _store.containsKey(key: _key);
    } catch (_) {
      return false;
    }
  }

  /// Runs the system authentication prompt — biometric with a device-credential
  /// (PIN / pattern / password) fallback. Returns true on success.
  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN / pattern / password fallback
          stickyAuth: true,
        ),
      );
    } catch (e) {
      dlog('system unlock auth error: $e');
      return false;
    }
  }

  /// Enables unlock: authenticate, then store the [passKey] securely.
  Future<bool> enable(String passKey, String reason) async {
    if (!await _authenticate(reason)) return false;
    await _store.write(key: _key, value: passKey);
    return true;
  }

  /// Disables unlock and removes the stored passkey.
  Future<void> disable() async {
    try {
      await _store.delete(key: _key);
    } catch (_) {}
  }

  /// Authenticates and returns the stored passkey, or null on failure / cancel.
  Future<String?> unlock(String reason) async {
    if (!await _authenticate(reason)) return null;
    try {
      return await _store.read(key: _key);
    } catch (_) {
      return null;
    }
  }
}
