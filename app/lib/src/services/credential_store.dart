import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Legacy, read-only migration source for Steam account passwords.
///
/// Older builds stored the optional Steam password in platform secure storage
/// (Android Keystore) keyed by steamid. The current model keeps the password in
/// the account's maFile (see [SteamGuardAccount.password]); on unlock,
/// `refreshSessions` migrates any leftover keystore password into the maFile and
/// this store is only read (and cleared on account removal), never written to by
/// current flows. It can be retired once no legacy accounts remain.
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
