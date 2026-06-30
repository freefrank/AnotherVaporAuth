import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores Steam account passwords in the platform secure storage (Android
/// Keystore) keyed by steamid, so a session can be re-established automatically
/// without retyping the password. Kept OUT of the maFile so exporting an account
/// never leaks the password.
class CredentialStore {
  final FlutterSecureStorage _store;
  CredentialStore({FlutterSecureStorage? store})
      : _store = store ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _key(int steamId) => 'ava.pwd.$steamId';

  Future<void> savePassword(int steamId, String password) =>
      _store.write(key: _key(steamId), value: password);

  Future<String?> password(int steamId) async {
    try {
      return await _store.read(key: _key(steamId));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(int steamId) => _store.delete(key: _key(steamId));
}
