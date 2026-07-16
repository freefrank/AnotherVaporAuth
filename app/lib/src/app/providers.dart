import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/crypto/vault_crypto.dart';
import '../core/models/manifest.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/confirmations_client.dart';
import '../core/protocol/family_groups_client.dart';
import '../core/protocol/inventory_client.dart';
import '../core/protocol/market_client.dart';
import '../core/protocol/trade_offers_client.dart';
import '../services/account_store.dart';
import '../skins/skin_spec.dart';
import '../services/auto_login.dart';
import '../services/avatar_service.dart';
import '../services/biometric_unlock.dart';
import '../services/credential_store.dart';
import '../core/entitlement.dart';
import '../services/debug_log.dart';
import '../services/entitlement_store.dart';
import '../services/play_channel.dart';
import '../services/pro_actions.dart';
import '../services/session_manager.dart';
import '../services/steam_api_client.dart';
import '../services/steam_time.dart';
import '../services/storage_provider.dart';
import '../services/vault_key_store.dart';
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

/// Keystore-backed holder for the vault DEK (PIN-wrapped).
final vaultKeyStoreProvider =
    Provider<VaultKeyStore>((ref) => VaultKeyStore());

/// Stores account passwords (keystore) for automatic session re-establishment.
final credentialStoreProvider =
    Provider<CredentialStore>((ref) => CredentialStore());

/// Headless session maintenance (refresh token → access token, or a full
/// re-login with the stored password + the account's own TOTP).
final autoLoginProvider =
    Provider<AutoLogin>((ref) => AutoLogin(ref.read(apiClientProvider)));

/// Steam inventory reader (games, wallet, items).
final inventoryClientProvider =
    Provider<InventoryClient>((ref) => InventoryClient(ref.read(apiClientProvider)));

/// Steam Community Market operations (price, sell, listings).
final marketClientProvider =
    Provider<MarketClient>((ref) => MarketClient(ref.read(apiClientProvider)));

/// Steam trade offers (list, accept, decline, cancel) client.
final tradeOffersClientProvider = Provider<TradeOffersClient>(
    (ref) => TradeOffersClient(ref.read(apiClientProvider)));

/// Mobile confirmations (trade / market listing) client.
final confirmationsClientProvider = Provider<ConfirmationsClient>(
    (ref) => ConfirmationsClient(ref.read(apiClientProvider)));

/// Steam family groups (invites, join, read-only group info) client.
final familyGroupsClientProvider = Provider<FamilyGroupsClient>(
    (ref) => FamilyGroupsClient(ref.read(apiClientProvider)));

/// Time alignment hook (overridable in tests to avoid network).
final timeAlignerProvider =
    Provider<Future<void> Function()>((ref) => SteamTime.align);

/// Persisted lightweight app settings (currently: locale override).
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => SettingsStore(ref.read(storageProvider)));

/// The styled skin layer (none / neon / pixel), persisted.
final skinProvider = NotifierProvider<SkinController, AvaSkin>(
    SkinController.new);

class SkinController extends Notifier<AvaSkin> {
  @override
  AvaSkin build() {
    ref.read(settingsStoreProvider).loadSkin().then((v) {
      if (!ref.mounted) return;
      for (final skin in AvaSkin.values) {
        if (v == skin.name) state = skin;
      }
      // Deliberately NO launcher-icon reconcile here. Toggling the alias the
      // current task was launched from removes the task on some OEMs
      // (ColorOS killed the app at every launch when 0.90's paywall gating
      // first made the startup value differ from the active alias). The icon
      // reconciles only when the app backgrounds — see the paused handler in
      // app.dart, the single place allowed to call LauncherIcon.apply.
    });
    // Default is the plain look since 0.90 (neon moved behind the paywall).
    return AvaSkin.none;
  }

  Future<void> setSkin(AvaSkin skin) async {
    state = skin;
    await ref.read(settingsStoreProvider).saveSkin(skin.name);
    // Deliberately NOT applying the launcher icon here: toggling launcher
    // aliases mid-session makes some launchers drop the task (feels like a
    // restart). The icon reconciles on next background/launch instead.
  }
}

/// The active skin's effect spec, loaded from the bundled JSON pack.
/// Null while loading and for the plain (no-skin) look.
final skinSpecProvider =
    NotifierProvider<SkinSpecController, SkinSpec?>(SkinSpecController.new);

class SkinSpecController extends Notifier<SkinSpec?> {
  @override
  SkinSpec? build() {
    final skin = ref.watch(effectiveSkinProvider);
    if (skin != AvaSkin.none) _load(skin);
    return null;
  }

  Future<void> _load(AvaSkin skin) async {
    try {
      final text = await rootBundle.loadString('assets/skins/${skin.name}.json');
      // Guard against a skin switch racing the asset load.
      if (ref.read(effectiveSkinProvider) == skin) state = SkinSpec.parse(text);
    } catch (e) {
      dlog('skin: failed to load ${skin.name}.json: $e');
    }
  }
}

/// Light/dark preference for the plain look (system / dark / light).
final brightnessModeProvider =
    NotifierProvider<BrightnessModeController, AvaBrightnessMode>(
        BrightnessModeController.new);

class BrightnessModeController extends Notifier<AvaBrightnessMode> {
  @override
  AvaBrightnessMode build() {
    ref.read(settingsStoreProvider).loadBrightnessMode().then((v) {
      for (final mode in AvaBrightnessMode.values) {
        if (v == mode.name) state = mode;
      }
    });
    return AvaBrightnessMode.system;
  }

  Future<void> setMode(AvaBrightnessMode mode) async {
    state = mode;
    await ref.read(settingsStoreProvider).saveBrightnessMode(mode.name);
  }
}

/// Wall clock, injectable for entitlement tests.
final clockProvider = Provider<DateTime Function()>(
    (ref) => () => DateTime.now().toUtc());

/// Entitlement worker HTTP client (overridden with a fake in tests).
final entitlementApiProvider =
    Provider<EntitlementApi>((ref) => DioEntitlementApi());

/// Ed25519 public key the app verifies entitlement tokens against.
final entitlementPublicKeyProvider =
    Provider<Uint8List>((ref) => entitlementPublicKeyBytes());

/// The stored, signature-checked entitlement token (null = none/invalid).
final entitlementTokenProvider =
    NotifierProvider<EntitlementTokenController, EntitlementToken?>(
        EntitlementTokenController.new);

class EntitlementTokenController extends Notifier<EntitlementToken?> {
  Timer? _refreshTimer;

  @override
  EntitlementToken? build() {
    ref.onDispose(() => _refreshTimer?.cancel());
    _load();
    return null;
  }

  Future<void> _load() async {
    final raw = await ref.read(settingsStoreProvider).loadEntitlementToken();
    if (!ref.mounted || raw == null) return;
    final token = EntitlementToken.tryParse(raw,
        publicKey: ref.read(entitlementPublicKeyProvider));
    state = token;
    if (token == null) return;
    final eval = evaluateEntitlement(token, ref.read(clockProvider)());
    if (eval.needsRefresh) {
      await refreshNow();
    }
    _scheduleDailyRefresh();
  }

  /// Adopts a token freshly issued by the worker (purchase / redeem /
  /// refresh flows). Returns false when it does not verify — the worker
  /// sent garbage or the embedded public key is out of date; the previous
  /// token stays in place.
  Future<bool> adopt(String raw) async {
    final token = EntitlementToken.tryParse(raw,
        publicKey: ref.read(entitlementPublicKeyProvider));
    if (token == null) return false;
    state = token;
    await ref.read(settingsStoreProvider).saveEntitlementToken(raw);
    _scheduleDailyRefresh();
    return true;
  }

  /// Rotates the current token against the worker. Terminal rejections
  /// (403: revoked / kicked device / subscription ended) drop the token;
  /// network failures keep it — the offline grace window covers those.
  Future<void> refreshNow() async {
    final token = state;
    if (token == null) return;
    try {
      final fresh = await ref
          .read(entitlementApiProvider)
          .refresh(token.raw, token.deviceId);
      await adopt(fresh);
    } on EntitlementApiException catch (e) {
      if (e.isTerminal) {
        state = null;
        await ref.read(settingsStoreProvider).clearEntitlementToken();
      }
    } catch (e) {
      dlog('entitlement: refresh failed, staying in grace: $e');
    }
  }

  void _scheduleDailyRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(hours: 24), (_) => refreshNow());
  }
}

/// Stable per-install device id for entitlement binding (created lazily).
final deviceIdProvider = FutureProvider<String>((ref) async {
  final settings = ref.read(settingsStoreProvider);
  final existing = await settings.loadDeviceId();
  if (existing != null && existing.isNotEmpty) return existing;
  final id = newDeviceId();
  await settings.saveDeviceId(id);
  return id;
});

/// What the UI gates Pro features on.
final proStatusProvider = Provider<ProStatus>((ref) {
  final token = ref.watch(entitlementTokenProvider);
  return evaluateEntitlement(token, ref.read(clockProvider)()).status;
});

/// Native play-flavor layer (billing / ads / sign-in).
final playChannelProvider = Provider<PlayChannel>((ref) => const PlayChannel());

/// Whether settings must expose the UMP privacy-options re-entry point
/// (play flavor, GDPR regions after a consent choice). Always false on cn.
final privacyOptionsRequiredProvider = FutureProvider<bool>(
    (ref) => ref.read(playChannelProvider).privacyOptionsRequired());

/// Purchase / redeem / rewarded orchestration for the paywall UI.
final proActionsProvider = Provider<ProActions>((ref) => ProActions(
      api: ref.read(entitlementApiProvider),
      play: ref.read(playChannelProvider),
      deviceId: () => ref.read(deviceIdProvider.future),
      adopt: (raw) => ref.read(entitlementTokenProvider.notifier).adopt(raw),
    ));

/// The skin actually rendered: neon/pixel are Pro perks since 0.90, so free
/// users fall back to the plain look. The stored selection is deliberately
/// kept — subscribing brings the chosen skin straight back.
final effectiveSkinProvider = Provider<AvaSkin>((ref) {
  final selected = ref.watch(skinProvider);
  if (selected == AvaSkin.none) return selected;
  return ref.watch(proStatusProvider) == ProStatus.free
      ? AvaSkin.none
      : selected;
});

/// One-time migration notice: the stored skin is a Pro perk this install
/// can no longer render (post-0.90 upgrade, no entitlement). Home shows a
/// banner while true; [SkinPaywallNoticeController.dismiss] persists.
final skinPaywallNoticeProvider =
    NotifierProvider<SkinPaywallNoticeController, bool>(
        SkinPaywallNoticeController.new);

class SkinPaywallNoticeController extends Notifier<bool> {
  bool _flagLoaded = false;
  bool _shownBefore = true; // pessimistic until the persisted flag loads

  @override
  bool build() {
    final degraded = ref.watch(skinProvider) != AvaSkin.none &&
        ref.watch(proStatusProvider) == ProStatus.free;
    if (!_flagLoaded) {
      _flagLoaded = true;
      ref.read(settingsStoreProvider).loadSkinProNoticeShown().then((shown) {
        if (!ref.mounted) return;
        _shownBefore = shown;
        ref.invalidateSelf();
      });
      return false;
    }
    return degraded && !_shownBefore;
  }

  Future<void> dismiss() async {
    _shownBefore = true;
    state = false;
    await ref.read(settingsStoreProvider).saveSkinProNoticeShown();
  }
}

/// User text-size step (small = pre-0.84 baseline), persisted.
final textSizeProvider =
    NotifierProvider<TextSizeController, AvaTextSize>(TextSizeController.new);

class TextSizeController extends Notifier<AvaTextSize> {
  @override
  AvaTextSize build() {
    ref.read(settingsStoreProvider).loadTextSize().then((v) {
      for (final size in AvaTextSize.values) {
        if (v == size.name) state = size;
      }
    });
    return AvaTextSize.small;
  }

  Future<void> setSize(AvaTextSize size) async {
    state = size;
    await ref.read(settingsStoreProvider).saveTextSize(size.name);
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

/// 长按确认开关（默认开），持久化到 app_settings.json。
final holdConfirmProvider =
    NotifierProvider<HoldConfirmController, bool>(HoldConfirmController.new);

class HoldConfirmController extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsStoreProvider).loadHoldConfirm().then((v) => state = v);
    return true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(settingsStoreProvider).saveHoldConfirm(enabled);
  }
}

/// 全局触觉反馈开关（默认开）。
final hapticsProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);

class HapticsController extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsStoreProvider).loadHaptics().then((v) => state = v);
    return true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(settingsStoreProvider).saveHaptics(enabled);
  }
}

/// The installed app version (from the platform package info).
final appVersionProvider = FutureProvider<String>(
    (ref) async => (await PackageInfo.fromPlatform()).version);

/// Bumped by settings → "replay tutorial"; the home screen re-arms its
/// first-run gesture walkthrough when this changes.
final tutorialReplayProvider =
    NotifierProvider<TutorialReplayController, int>(
        TutorialReplayController.new);

class TutorialReplayController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
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

/// Wipes an undecryptable vault back to a clean, unlocked store. Ordered so a
/// failure at any step can never brick the vault:
///   1. Commit a clean, non-vault manifest (atomic). This is the point of no
///      return — once it lands, bootstrap yields an unlocked empty store, so we
///      can never be stranded with a vault manifest whose DEK we already threw
///      away. If this very write fails, the original vault is untouched.
///   2. Best-effort delete of the now-orphaned payload files (a leftover maFile
///      is harmless — the fresh manifest references none).
///   3. Only now drop the keys — the store is already clean and unlocked, so a
///      failure here can't strand a vault behind a missing key.
@visibleForTesting
Future<void> performVaultReset({
  required StorageProvider storage,
  required Future<void> Function() clearKeys,
  required Future<void> Function() disableBiometric,
}) async {
  await AccountStore(storage, Manifest()).save();
  try {
    for (final f in await storage.listFiles()) {
      await storage.deleteFile(f);
    }
  } catch (_) {}
  await clearKeys();
  await disableBiometric();
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

  /// Last-resort escape hatch for a vault that can no longer be decrypted
  /// (e.g. data restored onto another device without its Keystore key, so the
  /// correct PIN is rejected forever). Deletes the wrapped key, the biometric
  /// passkey copy, the manifest and every maFile, then re-bootstraps into a
  /// clean, unlocked state. Settings survive. The user re-imports from their
  /// maFile backups; nothing on the Steam side is touched.
  Future<void> resetVault() async {
    await performVaultReset(
      storage: ref.read(storageProvider),
      clearKeys: () => ref.read(vaultKeyStoreProvider).clear(),
      disableBiometric: () => ref.read(biometricUnlockProvider).disable(),
    );
    ref.invalidateSelf();
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

  /// Persists manifest-level settings and notifies watchers in place. Never
  /// invalidate this provider for that: a full [build] re-runs the encrypted
  /// bootstrap path and would re-lock the app.
  Future<void> saveSettings() async {
    final data = state.value;
    if (data == null) return;
    await data.store.save();
    // Re-read: a concurrent refresh may have updated state during the await —
    // notifying with the pre-await snapshot would clobber it.
    final current = state.value ?? data;
    state = AsyncData(current.copyWith());
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

  /// Attempts to unlock an encrypted store with the 6-digit [pin].
  ///
  /// Vault store: the PIN unwraps the Keystore-held DEK. Legacy store: the PIN
  /// decrypts the CBC maFiles as before, and the store is then migrated to the
  /// vault scheme in the background.
  Future<bool> unlock(String pin) async {
    final data = state.value;
    if (data == null) return false;
    final store = data.store;
    final sw = Stopwatch()..start();

    if (store.isVault) {
      final dek = await ref.read(vaultKeyStoreProvider).unwrapWithPin(pin);
      if (dek == null) return false; // wrong PIN (GCM tag fails)
      store.setDek(dek);
      final accounts = store.entries.isEmpty
          ? const <SteamGuardAccount>[]
          : await store.getAllAccounts();
      if (store.entries.isNotEmpty && accounts.isEmpty) {
        dlog('unlock(vault): DEK ok but 0/${store.entries.length} decoded');
      }
      dlog('unlock(vault): ${sw.elapsedMilliseconds}ms, '
          '${accounts.length} accounts');
      state = AsyncData(
        data.copyWith(accounts: accounts, locked: false, passKey: pin),
      );
      Future.microtask(refreshSessions);
      Future.microtask(refreshAvatars);
      return true;
    }

    // Legacy (PIN-derived CBC) store.
    List<SteamGuardAccount> accounts;
    if (store.entries.isEmpty) {
      if (!await store.verifyPasskey(pin)) return false;
      accounts = const [];
    } else {
      // getAllAccounts validates the key (empty == wrong key).
      accounts = await store.getAllAccounts(passKey: pin);
      if (accounts.isEmpty) return false;
    }
    dlog('unlock(legacy): ${sw.elapsedMilliseconds}ms, '
        '${accounts.length} accounts');
    state = AsyncData(
      data.copyWith(accounts: accounts, locked: false, passKey: pin),
    );
    Future.microtask(refreshSessions);
    Future.microtask(refreshAvatars);
    // One-time upgrade of the weak PIN-derived scheme to the Keystore DEK vault.
    unawaited(_migrateToVault(pin, accounts));
    return true;
  }

  /// Establishes the vault (random DEK, PIN-wrapped in the Keystore) and
  /// re-encrypts every maFile under it. Used both to upgrade a legacy store and
  /// to set up a brand-new store's first PIN.
  Future<bool> _establishVault(
      String pin, List<SteamGuardAccount> accounts) async {
    final store = state.value?.store;
    if (store == null || store.isVault) return false;
    final dek = VaultCrypto.generateDek();
    await ref.read(vaultKeyStoreProvider).storePinWrap(pin, dek);
    await store.migrateToVault(dek, accounts);
    return true;
  }

  Future<void> _migrateToVault(
      String pin, List<SteamGuardAccount> accounts) async {
    try {
      final sw = Stopwatch()..start();
      if (await _establishVault(pin, accounts)) {
        dlog('migrated store to vault (DEK/GCM) in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      dlog('vault migrate failed: $e');
    }
  }

  Future<void> reload() async {
    final data = state.value;
    if (data == null) return;
    final accounts = await data.store.getAllAccounts(passKey: data.passKey);
    state = AsyncData(data.copyWith(accounts: accounts));
  }

  /// Imports a maFile and returns the resulting account, so callers can act on
  /// it right away (e.g. reactivating its session) without re-scanning the
  /// freshly reloaded account list.
  Future<SteamGuardAccount> importMaFile(String contents,
      {String? sourceName}) async {
    final data = state.value;
    if (data == null) {
      throw StateError('importMaFile called before the store is ready');
    }
    final account = await data.store
        .importMaFileContents(contents, data.passKey, sourceName: sourceName);
    await reload();
    unawaited(refreshAvatars());
    return account;
  }

  /// Drops a code-only account's synthetic-id placeholder entry after it has
  /// been re-saved under a real SteamID (post sign-in).
  Future<void> removeAccountBySteamId(int steamId) async {
    final data = state.value;
    if (data == null) return;
    await data.store.removeEntryById(steamId);
    await ref.read(credentialStoreProvider).clear(steamId);
    await reload();
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
    if (data == null || oldIndex < 0 || oldIndex >= data.accounts.length) {
      return;
    }
    // newIndex is already adjusted for the removed item (onReorderItem).
    data.store.moveEntry(oldIndex, newIndex);
    // Mirror the move in memory instead of reloading — a full reload decrypts
    // every account from disk and makes the dragged row visibly snap back.
    final accounts = [...data.accounts];
    final moved = accounts.removeAt(oldIndex);
    accounts.insert(newIndex.clamp(0, accounts.length), moved);
    state = AsyncData(data.copyWith(accounts: accounts));
    await data.store.save();
  }

  /// Persists an account back to disk (e.g. after a session refresh / link).
  /// Returns false if the write failed (disk full, read-only, manifest write
  /// error) — callers persisting a freshly-linked authenticator MUST check
  /// this before proceeding, or the secret is lost while Steam Guard may
  /// already be attached to the account.
  Future<bool> persistAccount(SteamGuardAccount account) async {
    final data = state.value;
    if (data == null) return false;
    final ok = await data.store
        .saveAccount(account, data.store.encrypted, passKey: data.passKey);
    if (!ok) return false;
    await reload();
    unawaited(refreshAvatars(steamIds: [account.steamId]));
    return true;
  }

  /// Changes (or sets) the unlock PIN.
  ///
  /// - Setting the first PIN on a fresh store establishes the vault directly.
  /// - Changing the PIN on a vault store re-wraps the DEK under the new PIN.
  /// - Legacy encrypted stores rotate the CBC key (and migrate to vault on the
  ///   next unlock).
  Future<bool> changePasskey(String? oldKey, String? newKey) async {
    final data = state.value;
    if (data == null || newKey == null) return false;
    final store = data.store;

    if (store.isVault) {
      final ok = await ref
          .read(vaultKeyStoreProvider)
          .rewrapPin(oldKey ?? '', newKey);
      if (ok) state = AsyncData(data.copyWith(passKey: newKey));
      return ok;
    }

    // First PIN on a brand-new store → go straight to the vault scheme.
    if (oldKey == null && !store.encrypted) {
      final ok = await _establishVault(newKey, data.accounts);
      if (ok) state = AsyncData(data.copyWith(passKey: newKey));
      return ok;
    }

    // Legacy rotate (migrates to vault on next unlock).
    final ok = await store.changeEncryptionKey(oldKey, newKey);
    if (ok) state = AsyncData(data.copyWith(passKey: newKey));
    return ok;
  }
}
