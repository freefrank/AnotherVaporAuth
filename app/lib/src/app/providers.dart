import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/steam_guard_account.dart';
import '../services/account_store.dart';
import '../services/auto_login.dart';
import '../services/avatar_service.dart';
import '../services/biometric_unlock.dart';
import '../services/credential_store.dart';
import '../services/debug_log.dart';
import '../services/session_manager.dart';
import '../services/steam_api_client.dart';
import '../services/steam_time.dart';
import '../services/storage_provider.dart';
import 'settings_store.dart';
import 'theme.dart';

/// Platform storage (maFiles location).
final storageProvider =
    Provider<StorageProvider>((ref) => StorageProvider.forPlatform());

/// Shared Steam HTTP client.
final apiClientProvider = Provider<SteamApiClient>((ref) => SteamApiClient());

/// Resolves Steam profile avatars (public community XML, no API key).
final avatarServiceProvider = Provider<AvatarService>((ref) => AvatarService());

/// System-credential (biometric / device PIN) app unlock.
final biometricUnlockProvider =
    Provider<BiometricUnlock>((ref) => BiometricUnlock());

/// Stores account passwords (keystore) for automatic session re-establishment.
final credentialStoreProvider =
    Provider<CredentialStore>((ref) => CredentialStore());

/// Headless session maintenance (refresh token → access token, or a full
/// re-login with the stored password + the account's own TOTP).
final autoLoginProvider =
    Provider<AutoLogin>((ref) => AutoLogin(ref.read(apiClientProvider)));

/// Time alignment hook (overridable in tests to avoid network).
final timeAlignerProvider =
    Provider<Future<void> Function()>((ref) => SteamTime.align);

/// Persisted lightweight app settings (currently: locale override).
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => SettingsStore(ref.read(storageProvider)));

/// The active UI theme variant (neon / pixel), persisted.
final themeVariantProvider =
    NotifierProvider<ThemeController, SdaThemeVariant>(ThemeController.new);

class ThemeController extends Notifier<SdaThemeVariant> {
  @override
  SdaThemeVariant build() {
    ref.read(settingsStoreProvider).loadTheme().then((v) {
      if (v == 'pixel') state = SdaThemeVariant.pixel;
      if (v == 'neon') state = SdaThemeVariant.neon;
    });
    return SdaThemeVariant.neon;
  }

  Future<void> setVariant(SdaThemeVariant variant) async {
    state = variant;
    await ref.read(settingsStoreProvider).saveTheme(variant.name);
  }
}

/// The active UI locale (null = follow system).
final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    // Load asynchronously; default to system until loaded.
    ref.read(settingsStoreProvider).loadLocale().then((code) {
      if (code != null) state = Locale(code);
    });
    return null;
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(settingsStoreProvider).saveLocale(locale?.languageCode);
  }
}

/// A 1-second tick used to refresh codes and countdowns.
final tickProvider = StreamProvider<int>((ref) async* {
  yield SteamTime.currentSteamTime;
  yield* Stream.periodic(
    const Duration(seconds: 1),
    (_) => SteamTime.currentSteamTime,
  );
});

/// Top-level app data after bootstrap.
class AppData {
  final AccountStore store;
  final List<SteamGuardAccount> accounts;
  final bool locked; // encrypted and not yet unlocked
  final String? passKey; // held in memory only while unlocked
  final bool privacyAccepted; // first-run Privacy Policy gate

  const AppData({
    required this.store,
    required this.accounts,
    required this.locked,
    this.passKey,
    this.privacyAccepted = true,
  });

  bool get encrypted => store.encrypted;

  AppData copyWith({
    List<SteamGuardAccount>? accounts,
    bool? locked,
    String? passKey,
    bool? privacyAccepted,
  }) =>
      AppData(
        store: store,
        accounts: accounts ?? this.accounts,
        locked: locked ?? this.locked,
        passKey: passKey ?? this.passKey,
        privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      );
}

/// Bootstraps and owns the account list / unlock state.
final appControllerProvider =
    AsyncNotifierProvider<AppController, AppData>(AppController.new);

class AppController extends AsyncNotifier<AppData> {
  @override
  Future<AppData> build() async {
    final storage = ref.read(storageProvider);
    final store = await AccountStore.load(storage);
    final privacyAccepted =
        await ref.read(settingsStoreProvider).loadPrivacyAccepted();
    // No network until the Privacy Policy is accepted.
    if (privacyAccepted) {
      unawaited(ref.read(timeAlignerProvider)());
    }

    if (store.encrypted) {
      return AppData(
          store: store,
          accounts: const [],
          locked: true,
          privacyAccepted: privacyAccepted);
    }
    final accounts = await store.getAllAccounts();
    if (privacyAccepted) {
      Future.microtask(refreshSessions);
      Future.microtask(refreshAvatars);
    }
    return AppData(
        store: store,
        accounts: accounts,
        locked: false,
        privacyAccepted: privacyAccepted);
  }

  /// Records first-run acceptance of the Privacy Policy, then kicks off the
  /// network work that was held back until consent. Updates state immediately
  /// and persists in the background.
  Future<void> acceptPrivacy() async {
    final data = state.value;
    if (data != null) {
      state = AsyncData(data.copyWith(privacyAccepted: true));
    }
    unawaited(ref.read(settingsStoreProvider).savePrivacyAccepted(true));
    unawaited(ref.read(timeAlignerProvider)());
    Future.microtask(refreshSessions);
    Future.microtask(refreshAvatars);
  }

  bool _refreshingSessions = false;

  /// Proactively keeps each account's Steam session fresh: for accounts whose
  /// access token is stale/expiring, refresh it from the refresh token, or (when
  /// that is dead and a password is stored) do a full headless re-login. Runs on
  /// app open and unlock; on-demand refreshes happen where a 401 is hit.
  Future<void> refreshSessions() async {
    if (_refreshingSessions) return;
    final data = state.value;
    if (data == null || data.locked) return;
    _refreshingSessions = true;
    try {
      final auto = ref.read(autoLoginProvider);
      final creds = ref.read(credentialStoreProvider);
      var changed = false;
      for (final acc in data.accounts) {
        if (acc.steamId == 0) continue;
        var accChanged = false;
        // One-time migration: earlier builds stored the password in the keystore;
        // move it into the maFile so it travels with the account.
        if ((acc.password ?? '').isEmpty) {
          final legacy = await creds.password(acc.steamId);
          if (legacy != null && legacy.isNotEmpty) {
            acc.password = legacy;
            accChanged = true;
          }
        }
        // Refresh the token only when it's stale/expiring.
        if (AutoLogin.accessTokenStale(acc.session.accessToken)) {
          final before = acc.session.accessToken;
          final outcome = await auto.ensureSession(acc);
          if (outcome == AutoLoginOutcome.ok &&
              acc.session.accessToken != before) {
            accChanged = true;
          }
        }
        if (accChanged) {
          await data.store
              .saveAccount(acc, data.store.encrypted, passKey: data.passKey);
          changed = true;
        }
      }
      if (changed && state.value != null) {
        final accounts = await state.value!.store
            .getAllAccounts(passKey: state.value!.passKey);
        state = AsyncData(state.value!.copyWith(accounts: accounts));
      }
    } finally {
      _refreshingSessions = false;
    }
  }

  bool _refreshingAvatars = false;

  /// Re-resolves each account's Steam avatar and equipped avatar frame, then
  /// refreshes state so the UI shows them. Called on app open, unlock,
  /// pull-to-refresh and after adding an account. Pass [steamIds] to refresh
  /// only specific accounts (e.g. a just-added one).
  Future<void> refreshAvatars({Iterable<int>? steamIds}) async {
    if (_refreshingAvatars) return;
    final data = state.value;
    if (data == null || data.locked) return;
    _refreshingAvatars = true;
    try {
      final svc = ref.read(avatarServiceProvider);
      final only = steamIds?.toSet();
      var changed = false;
      for (final acc in data.accounts) {
        if (acc.steamId == 0) continue;
        if (only != null && !only.contains(acc.steamId)) continue;
        var accChanged = false;
        final profile = await svc.fetchProfile(acc.steamId);
        if (profile.avatarUrl != null && profile.avatarUrl != acc.avatarUrl) {
          acc.avatarUrl = profile.avatarUrl;
          accChanged = true;
        }
        if (profile.personaName != null &&
            profile.personaName != acc.personaName) {
          acc.personaName = profile.personaName;
          accChanged = true;
        }
        // The frame/animated avatar need a valid access token; on 401 refresh
        // once and retry.
        EquippedItems items;
        try {
          items =
              await svc.fetchEquippedItems(acc.steamId, acc.session.accessToken);
        } on FrameUnauthorized {
          items = const EquippedItems();
          final refreshed =
              await SessionManager(ref.read(apiClientProvider))
                  .refresh(acc.session);
          if (refreshed) {
            accChanged = true; // persist the new token
            try {
              items = await svc.fetchEquippedItems(
                  acc.steamId, acc.session.accessToken);
            } catch (_) {/* leave items unchanged */}
          }
        }
        // A null value means "not equipped / unresolved" — keep the cached one
        // rather than dropping a good value on a transient failure.
        if (items.frameUrl != null && items.frameUrl != acc.avatarFrameUrl) {
          acc.avatarFrameUrl = items.frameUrl;
          accChanged = true;
        }
        if (items.animatedAvatarUrl != null &&
            items.animatedAvatarUrl != acc.animatedAvatarUrl) {
          acc.animatedAvatarUrl = items.animatedAvatarUrl;
          accChanged = true;
        }
        if (accChanged) {
          await data.store
              .saveAccount(acc, data.store.encrypted, passKey: data.passKey);
          changed = true;
        }
      }
      if (changed && state.value != null) {
        final accounts = await state.value!.store
            .getAllAccounts(passKey: state.value!.passKey);
        state = AsyncData(state.value!.copyWith(accounts: accounts));
      }
    } finally {
      _refreshingAvatars = false;
    }
  }

  /// Attempts to unlock an encrypted store with [passKey].
  Future<bool> unlock(String passKey) async {
    final data = state.value;
    if (data == null) return false;
    final store = data.store;
    final sw = Stopwatch()..start();
    List<SteamGuardAccount> accounts;
    if (store.entries.isEmpty) {
      if (!await store.verifyPasskey(passKey)) return false;
      accounts = const [];
    } else {
      // getAllAccounts validates the key (empty == wrong key), so no separate
      // verifyPasskey derivation is needed.
      accounts = await store.getAllAccounts(passKey: passKey);
      if (accounts.isEmpty) return false;
    }
    dlog('unlock: decrypt ${sw.elapsedMilliseconds}ms '
        '(kdf=${store.manifest.kdfIterations}, ${accounts.length} accounts)');
    state = AsyncData(
      data.copyWith(accounts: accounts, locked: false, passKey: passKey),
    );
    Future.microtask(refreshSessions);
    Future.microtask(refreshAvatars);
    // One-time migration of an old high-rounds store to the fast PIN scheme.
    if (store.manifest.kdfIterations > AccountStore.avaIterations) {
      unawaited(_migrateKdf(passKey, accounts));
    }
    return true;
  }

  Future<void> _migrateKdf(
      String passKey, List<SteamGuardAccount> accounts) async {
    final store = state.value?.store;
    if (store == null) return;
    try {
      final sw = Stopwatch()..start();
      await store.reencrypt(passKey, accounts);
      dlog('kdf migrated to ${store.manifest.kdfIterations} '
          'in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      dlog('kdf migrate failed: $e');
    }
  }

  Future<void> reload() async {
    final data = state.value;
    if (data == null) return;
    final accounts = await data.store.getAllAccounts(passKey: data.passKey);
    state = AsyncData(data.copyWith(accounts: accounts));
  }

  Future<void> importMaFile(String contents) async {
    final data = state.value;
    if (data == null) return;
    await data.store.importMaFileContents(contents, data.passKey);
    await reload();
    unawaited(refreshAvatars());
  }

  Future<void> removeAccount(SteamGuardAccount account) async {
    final data = state.value;
    if (data == null) return;
    await data.store.removeAccount(account);
    await ref.read(credentialStoreProvider).clear(account.steamId);
    await reload();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final data = state.value;
    if (data == null) return;
    // newIndex is already adjusted for the removed item (onReorderItem).
    data.store.moveEntry(oldIndex, newIndex);
    await data.store.save();
    await reload();
  }

  /// Persists an account back to disk (e.g. after a session refresh / link).
  Future<void> persistAccount(SteamGuardAccount account) async {
    final data = state.value;
    if (data == null) return;
    await data.store
        .saveAccount(account, data.store.encrypted, passKey: data.passKey);
    await reload();
    unawaited(refreshAvatars(steamIds: [account.steamId]));
  }

  /// Changes (or sets/removes) the encryption passkey.
  Future<bool> changePasskey(String? oldKey, String? newKey) async {
    final data = state.value;
    if (data == null) return false;
    final ok = await data.store.changeEncryptionKey(oldKey, newKey);
    if (ok) {
      state = AsyncData(data.copyWith(passKey: newKey));
    }
    return ok;
  }
}
