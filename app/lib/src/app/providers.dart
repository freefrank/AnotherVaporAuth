import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/steam_guard_account.dart';
import '../services/account_store.dart';
import '../services/avatar_service.dart';
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

  const AppData({
    required this.store,
    required this.accounts,
    required this.locked,
    this.passKey,
  });

  bool get encrypted => store.encrypted;

  AppData copyWith({
    List<SteamGuardAccount>? accounts,
    bool? locked,
    String? passKey,
  }) =>
      AppData(
        store: store,
        accounts: accounts ?? this.accounts,
        locked: locked ?? this.locked,
        passKey: passKey ?? this.passKey,
      );
}

/// Bootstraps and owns the account list / unlock state.
final appControllerProvider =
    AsyncNotifierProvider<AppController, AppData>(AppController.new);

class AppController extends AsyncNotifier<AppData> {
  @override
  Future<AppData> build() async {
    // Align Steam time in the background (does not block first paint long).
    unawaited(ref.read(timeAlignerProvider)());
    final storage = ref.read(storageProvider);
    final store = await AccountStore.load(storage);

    if (store.encrypted) {
      return AppData(store: store, accounts: const [], locked: true);
    }
    final accounts = await store.getAllAccounts();
    Future.microtask(_fetchMissingAvatars);
    return AppData(store: store, accounts: accounts, locked: false);
  }

  /// Lazily resolves + caches each account's Steam avatar (for accounts that
  /// don't have one yet), then refreshes state so the UI shows it.
  Future<void> _fetchMissingAvatars() async {
    final data = state.value;
    if (data == null || data.locked) return;
    final svc = ref.read(avatarServiceProvider);
    var changed = false;
    for (final acc in data.accounts) {
      if (acc.steamId == 0) continue;
      if (acc.avatarUrl != null && acc.avatarUrl!.isNotEmpty) continue;
      final url = await svc.fetchAvatarUrl(acc.steamId);
      if (url != null) {
        acc.avatarUrl = url;
        await data.store
            .saveAccount(acc, data.store.encrypted, passKey: data.passKey);
        changed = true;
      }
    }
    if (changed && state.value != null) {
      final accounts =
          await state.value!.store.getAllAccounts(passKey: state.value!.passKey);
      state = AsyncData(state.value!.copyWith(accounts: accounts));
    }
  }

  /// Attempts to unlock an encrypted store with [passKey].
  Future<bool> unlock(String passKey) async {
    final data = state.value;
    if (data == null) return false;
    final ok = await data.store.verifyPasskey(passKey);
    if (!ok) return false;
    final accounts = await data.store.getAllAccounts(passKey: passKey);
    state = AsyncData(
      data.copyWith(accounts: accounts, locked: false, passKey: passKey),
    );
    Future.microtask(_fetchMissingAvatars);
    return true;
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
  }

  Future<void> removeAccount(SteamGuardAccount account) async {
    final data = state.value;
    if (data == null) return;
    await data.store.removeAccount(account);
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
