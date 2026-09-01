import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
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
import '../core/protocol/sessions_client.dart';
import '../core/protocol/store_key_client.dart';
import '../core/protocol/trade_offers_client.dart';
import '../services/account_store.dart';
import '../skins/skin_spec.dart';
import '../services/auto_login.dart';
import '../services/avatar_service.dart';
import '../services/biometric_unlock.dart';
import '../services/credential_store.dart';
import '../core/entitlement.dart';
import '../core/update_check.dart';
import '../services/debug_log.dart';
import '../services/entitlement_store.dart';
import '../services/play_channel.dart';
import '../services/pro_actions.dart';
import '../services/update_service.dart';
import '../services/screen_security.dart';
import '../services/session_manager.dart';
import '../services/steam_api_client.dart';
import '../services/window_service.dart';
import '../services/steam_time.dart';
import '../services/storage_provider.dart';
import '../services/vault_key_store.dart';
import 'settings_store.dart';
import 'theme.dart';

/// Platform storage (maFiles location).
final storageProvider =
    Provider<StorageProvider>((ref) => StorageProvider.forPlatform());

/// The desktop window-geometry keeper, overridden in main() on desktop.
/// Null elsewhere — mobile has no window to remember.
final windowServiceProvider = Provider<WindowService?>((ref) => null);

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

/// Device / session management (read-only device list; IAuthenticationService).
final sessionsClientProvider = Provider<SessionsClient>(
    (ref) => SessionsClient(ref.read(apiClientProvider)));

/// Steam product-key (CD key) activation via the store's ajax endpoint.
final storeKeyClientProvider = Provider<StoreKeyClient>(
    (ref) => StoreKeyClient(ref.read(apiClientProvider)));

/// Time alignment hook (overridable in tests to avoid network).
final timeAlignerProvider =
    Provider<Future<void> Function()>((ref) => SteamTime.align);

/// Persisted lightweight app settings (currently: locale override).
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => SettingsStore(ref.read(storageProvider)));

/// Shared shape for every scalar setting persisted in app_settings.json:
/// publish the default synchronously, apply the stored value when the async
/// load lands (ref.mounted-guarded — the provider can be disposed before the
/// file read completes), write through on set. Subclasses only supply the
/// default + load/save closures (and keep their call-site setter names).
class PersistedSettingController<T> extends Notifier<T> {
  final T _defaultValue;
  final Future<T?> Function(SettingsStore store) _load;
  final Future<void> Function(SettingsStore store, T value) _save;

  PersistedSettingController(this._defaultValue, this._load, this._save);

  @override
  T build() {
    _load(ref.read(settingsStoreProvider)).then((v) {
      if (!ref.mounted || v == null) return;
      state = v;
    });
    return _defaultValue;
  }

  Future<void> set(T value) async {
    state = value;
    await _save(ref.read(settingsStoreProvider), value);
  }
}

/// Enum lookup by persisted name; null when the stored value is absent or no
/// longer a member (the controller then keeps its default).
T? _enumByName<T extends Enum>(List<T> values, String? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// The styled skin layer (none / neon / pixel), persisted.
final skinProvider = NotifierProvider<SkinController, AvaSkin>(
    SkinController.new);

/// Pure persistence since 0.90.1 — launcher-icon syncing that once hooked in
/// here was retired; see the retirement note in app.dart before reviving it.
class SkinController extends PersistedSettingController<AvaSkin> {
  SkinController()
      : super(
          // Default is the plain look since 0.90 (neon moved behind the paywall).
          AvaSkin.none,
          (s) async => _enumByName(AvaSkin.values, await s.loadSkin()),
          (s, v) => s.saveSkin(v.name),
        );

  Future<void> setSkin(AvaSkin skin) => set(skin);
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

class BrightnessModeController
    extends PersistedSettingController<AvaBrightnessMode> {
  BrightnessModeController()
      : super(
          AvaBrightnessMode.system,
          (s) async =>
              _enumByName(AvaBrightnessMode.values, await s.loadBrightnessMode()),
          (s, v) => s.saveBrightnessMode(v.name),
        );

  Future<void> setMode(AvaBrightnessMode mode) => set(mode);
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

  /// A stored token that failed local verification (e.g. the embedded
  /// public key rotated out from under it). Still refreshable: the worker
  /// verifies with its own key. Cleared only on a definitive 403.
  String? _pendingRaw;

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
    if (token == null) {
      // Stored but locally unverifiable — never strand a paying user:
      // ask the worker to re-issue; keep the raw for retries.
      _pendingRaw = raw;
      await refreshNow();
      _scheduleDailyRefresh();
      return;
    }
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
    // Never trade a longer entitlement for a shorter one. Every acquisition
    // path lands here, and without this guard the LAST action wins: watching
    // a rewarded ad (VIP until +3d) and then tapping subscribe replaced the
    // 3-day token with the subscription's current period end — for a Play
    // license tester that period is FIVE MINUTES, so "buying Pro" visibly
    // shortened Pro (observed on-device 2026-08-16). Worse, a lifetime beta
    // token (proUntil null) would lose to anything. Keeping the longer token
    // is safe: the action still succeeded server-side, the purchase stays
    // bound on the worker, and restore can re-adopt it whenever it actually
    // outlasts what we hold. Tiers are equivalent today (vip = time-boxed
    // pro); revisit the comparison if that ever changes.
    final current = state;
    if (current != null) {
      final currentUntil =
          current.proUntil ?? DateTime.fromMillisecondsSinceEpoch(1 << 52);
      final newUntil =
          token.proUntil ?? DateTime.fromMillisecondsSinceEpoch(1 << 52);
      final now = ref.read(clockProvider)();
      if (currentUntil.isAfter(now) && currentUntil.isAfter(newUntil)) {
        dlog('entitlement: kept ${current.tier.name} until $currentUntil '
            'over ${token.tier.name} until $newUntil');
        _scheduleDailyRefresh();
        return true;
      }
    }
    state = token;
    await ref.read(settingsStoreProvider).saveEntitlementToken(raw);
    _scheduleDailyRefresh();
    return true;
  }

  /// Rotates the current token against the worker. Terminal rejections
  /// (403: revoked / kicked device / subscription ended / not our token)
  /// drop the token; network failures keep it — the offline grace window
  /// covers those. Also retries a stored-but-unverifiable raw
  /// ([_pendingRaw]) so an embedded-key rotation can heal itself.
  Future<void> refreshNow() async {
    final token = state;
    final raw = token?.raw ?? _pendingRaw;
    if (raw == null) return;
    try {
      final String deviceId =
          token?.deviceId ?? await ref.read(deviceIdProvider.future);
      final fresh =
          await ref.read(entitlementApiProvider).refresh(raw, deviceId);
      if (await adopt(fresh)) _pendingRaw = null;
    } on EntitlementApiException catch (e) {
      if (e.isTerminal) {
        _pendingRaw = null;
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
  // loadDeviceId throws on a read failure rather than returning null, so a
  // transient error propagates (the provider re-evaluates) instead of minting
  // a fresh id — which would rebind Pro to a device the worker never saw.
  final existing = await settings.loadDeviceId();
  if (existing != null && existing.isNotEmpty) return existing;
  final id = newDeviceId();
  await settings.saveDeviceId(id);
  return id;
});

/// Dev-only Pro unlock: a debug build passed `--dart-define=AVA_DEV_PRO=true`
/// reports Pro so the paid skins/themes are viewable without a real
/// entitlement. Double-gated — the define is absent from release builds AND
/// tests (neither passes it), and [kDebugMode] is compile-time false in
/// release/profile, so it can never ship or skew the gating tests.
const _devProUnlock = bool.fromEnvironment('AVA_DEV_PRO') && kDebugMode;

/// What the UI gates Pro features on. Schedules its own re-evaluation at
/// the next moment the verdict can change (entitlement end, refresh
/// deadline, end of offline grace): a token expiring while the app runs
/// must flip Pro off without waiting for a restart.
final proStatusProvider = Provider<ProStatus>((ref) {
  if (_devProUnlock) return ProStatus.pro;
  final token = ref.watch(entitlementTokenProvider);
  final now = ref.read(clockProvider)();
  if (token != null) {
    final boundaries = [
      if (token.proUntil != null) token.proUntil!,
      token.expiresAt,
      token.expiresAt.add(entitlementGrace),
    ].where((b) => b.isAfter(now));
    if (boundaries.isNotEmpty) {
      final next = boundaries.reduce((a, b) => a.isBefore(b) ? a : b);
      // +1s so the re-evaluation lands strictly past the boundary
      // (evaluateEntitlement flips exactly at proUntil / after exp+grace).
      final timer = Timer(
          next.difference(now) + const Duration(seconds: 1),
          ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
  return evaluateEntitlement(token, now).status;
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
      deviceClass: deviceClassForPlatform(),
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

class TextSizeController extends PersistedSettingController<AvaTextSize> {
  TextSizeController()
      : super(
          AvaTextSize.small,
          (s) async => _enumByName(AvaTextSize.values, await s.loadTextSize()),
          (s, v) => s.saveTextSize(v.name),
        );

  Future<void> setSize(AvaTextSize size) => set(size);
}

/// The active UI locale (null = follow system).
final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends PersistedSettingController<Locale?> {
  LocaleController()
      : super(
          // Follow the system until (and unless) a stored override loads.
          null,
          (s) async => localeFromTag(await s.loadLocale()),
          // Persist the full BCP-47 tag. Storing only languageCode silently
          // dropped the script subtag, so picking 繁體中文 came back as
          // 简体中文 on the next launch — 'zh-Hant' collapsed to 'zh'.
          (s, v) => s.saveLocale(v?.toLanguageTag()),
        );

  Future<void> setLocale(Locale? locale) => set(locale);
}

/// One row of the settings language picker.
class SelectableLocale {
  /// The language's name in that language — a user stranded in a script they
  /// cannot read still has to be able to pick their way back out.
  final String label;
  final Locale locale;
  const SelectableLocale(this.label, this.locale);
}

/// Every locale AVA ships an ARB for, in picker order. Adding a language means
/// touching three places: the ARB, this list, and the Steam language map in
/// `_SteamLanguageSync` (app.dart) — miss the last one and the UI translates
/// while Steam-served item names stay English.
const kSelectableLocales = <SelectableLocale>[
  SelectableLocale('English', Locale('en')),
  SelectableLocale('简体中文', Locale('zh')),
  SelectableLocale('繁體中文',
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
  SelectableLocale('Deutsch', Locale('de')),
  SelectableLocale('Français', Locale('fr')),
  SelectableLocale('Español', Locale('es')),
  SelectableLocale('Русский', Locale('ru')),
];

/// Parses a stored locale tag ('en', 'zh', 'zh-Hant') back into a [Locale].
///
/// A four-letter subtag is a script (Hant/Hans); anything else is ignored,
/// since AVA ships no country-specific locales. Plain language codes are the
/// pre-1.0 stored format and still parse, so upgrades keep their choice.
@visibleForTesting
Locale? localeFromTag(String? tag) {
  if (tag == null || tag.isEmpty) return null;
  final parts = tag.split(RegExp('[-_]'));
  final language = parts.first;
  if (language.isEmpty) return null;
  for (final part in parts.skip(1)) {
    if (part.length == 4) {
      return Locale.fromSubtags(languageCode: language, scriptCode: part);
    }
  }
  return Locale(language);
}

/// 长按确认开关（默认开），持久化到 app_settings.json。
final holdConfirmProvider =
    NotifierProvider<HoldConfirmController, bool>(HoldConfirmController.new);

class HoldConfirmController extends PersistedSettingController<bool> {
  HoldConfirmController()
      : super(true, (s) => s.loadHoldConfirm(), (s, v) => s.saveHoldConfirm(v));
}

/// Launch-time update check (default on; the check itself is a single GET
/// against a no-logging endpoint — see update_service.dart).
final updateCheckEnabledProvider =
    NotifierProvider<UpdateCheckEnabledController, bool>(
        UpdateCheckEnabledController.new);

class UpdateCheckEnabledController extends PersistedSettingController<bool> {
  UpdateCheckEnabledController()
      : super(true, (s) => s.loadUpdateCheckEnabled(),
            (s, v) => s.saveUpdateCheckEnabled(v));
}

/// 删除账号需长按确认（默认开），持久化到 app_settings.json。
final deleteHoldProvider =
    NotifierProvider<DeleteHoldController, bool>(DeleteHoldController.new);

class DeleteHoldController extends PersistedSettingController<bool> {
  DeleteHoldController()
      : super(true, (s) => s.loadDeleteHold(), (s, v) => s.saveDeleteHold(v));
}

/// 全局触觉反馈开关（默认开）。
final hapticsProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);

class HapticsController extends PersistedSettingController<bool> {
  HapticsController()
      : super(true, (s) => s.loadHaptics(), (s, v) => s.saveHaptics(v));
}

/// 阻止截屏/录屏（Android FLAG_SECURE，**默认关**）。
final blockScreenshotsProvider = NotifierProvider<BlockScreenshotsController,
    bool>(BlockScreenshotsController.new);

class BlockScreenshotsController extends PersistedSettingController<bool> {
  BlockScreenshotsController()
      : super(
          kScreenSecurityDefault,
          (s) => s.loadBlockScreenshots(),
          (s, v) => s.saveBlockScreenshots(v),
        );

  @override
  bool build() {
    final initial = super.build();
    // Covers both transitions that matter: the async load settling on a
    // stored `true`, and the user flipping the switch.
    listenSelf((_, next) => ScreenSecurity.apply(next));
    // listenSelf only fires on *changes*, so push the starting value too —
    // a recreated activity comes back with a fresh window whose flag is
    // clear, and the notifier may already be holding the user's choice.
    ScreenSecurity.apply(initial);
    return initial;
  }
}

/// The installed app version (from the platform package info).
final appVersionProvider = FutureProvider<String>(
    (ref) async => (await PackageInfo.fromPlatform()).version);

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Result of the launch-time update check. Stays [UpdateDecision.none] until
/// (and unless) a check completes with a strictly newer version; every
/// failure mode of the check leaves it untouched.
final updateDecisionProvider =
    NotifierProvider<UpdateController, UpdateDecision>(UpdateController.new);

class UpdateController extends Notifier<UpdateDecision> {
  @override
  UpdateDecision build() => UpdateDecision.none;

  /// The launch-time check, fired after the first frame (AvaApp.initState)
  /// and NEVER awaited from any startup path — offline launch is a promise
  /// this app has shipped in writing.
  Future<void> runStartupCheck({String? osOverride}) async {
    try {
      final settings = ref.read(settingsStoreProvider);
      if (!await settings.loadUpdateCheckEnabled()) return;
      // PackageInfo can throw where the plugin is absent (tests, exotic
      // embedders) — feedback_service hit the same thing. No version, no
      // check: the comparison would be meaningless.
      final decision = await ref.read(updateServiceProvider).check(
            currentVersion: await ref.read(appVersionProvider.future),
            channelKey:
                updateChannelKey(os: osOverride ?? Platform.operatingSystem),
          );
      if (decision.available && ref.mounted) state = decision;
    } catch (e) {
      // Fire-and-forget from startup: nothing above this may ever throw
      // into an unawaited future.
      dlog('update check: startup hook skipped ($e)');
    }
  }

  /// Hides the banner for THIS session only. With auto-check on, the next
  /// launch announces again (2026-08-15 owner decision — the persisted
  /// per-version skip made one stray tap silence an update forever, which is
  /// exactly what happened during on-device testing). The off switch in
  /// settings is the way to stop the announcements.
  void dismiss() => state = UpdateDecision.none;
}

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

/// Last-chance copy of a moved-in authenticator's secrets when the local save
/// failed. Non-null ⇒ the root swaps to MoveInRescueScreen until the user
/// explicitly confirms they copied them. Held in memory only, never persisted.
final moveInRescueProvider =
    NotifierProvider<MoveInRescueController, ({String code, String secret})?>(
        MoveInRescueController.new);

class MoveInRescueController extends Notifier<({String code, String secret})?> {
  @override
  ({String code, String secret})? build() => null;
  void set(({String code, String secret}) v) => state = v;
  void clear() => state = null;
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
/// Revision of the Privacy Policy notice shown on the consent screen.
///
/// Bump this whenever the *substance* of what the notice tells the user
/// changes — not for typo fixes. Everyone who accepted an older revision then
/// sees the "policy updated" variant of the screen before continuing.
///
///  1. Original first-run notice. Claimed AVA "has no backend of its own"
///     and "connects only to Valve's Steam servers", neither of which was
///     true — there are two developer-run services, and the Play build shows
///     ads. Consent obtained under it does not carry over.
///  2. Corrected notice naming both services and the ads (2026-08).
// v3 (v1.2): the notice's "never uploaded" gained its sync qualifier when
// WebDAV sync shipped. Everyone who accepted v1/v2 gets the lightweight
// "notice updated" screen once — §9 of the policy promised exactly this
// before any sync feature could be enabled.
const int kPrivacyNoticeVersion = 3;

class AppData {
  final AccountStore store;
  final List<SteamGuardAccount> accounts;
  final bool locked; // encrypted and not yet unlocked
  final String? passKey; // held in memory only while unlocked
  /// Which revision of the Privacy Policy notice this install has accepted;
  /// 0 = never. See [kPrivacyNoticeVersion].
  final int privacyVersion;

  const AppData({
    required this.store,
    required this.accounts,
    required this.locked,
    this.passKey,
    this.privacyVersion = kPrivacyNoticeVersion,
  });

  bool get encrypted => store.encrypted;

  /// Whether the current notice has been accepted — the gate for showing the
  /// app at all, and for touching the network.
  bool get privacyAccepted => privacyVersion >= kPrivacyNoticeVersion;

  /// Accepted an *earlier* notice: they have used AVA before, so the screen
  /// should tell them what changed rather than onboard them again.
  bool get privacyNeedsUpdate =>
      privacyVersion > 0 && privacyVersion < kPrivacyNoticeVersion;

  AppData copyWith({
    List<SteamGuardAccount>? accounts,
    bool? locked,
    String? passKey,
    int? privacyVersion,
  }) =>
      AppData(
        store: store,
        accounts: accounts ?? this.accounts,
        locked: locked ?? this.locked,
        passKey: passKey ?? this.passKey,
        privacyVersion: privacyVersion ?? this.privacyVersion,
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
    final privacyVersion =
        await ref.read(settingsStoreProvider).loadPrivacyAcceptedVersion();
    final privacyAccepted = privacyVersion >= kPrivacyNoticeVersion;
    // No network until the Privacy Policy is accepted.
    if (privacyAccepted) {
      unawaited(ref.read(timeAlignerProvider)());
    }

    if (store.encrypted) {
      return AppData(
          store: store,
          accounts: const [],
          locked: true,
          privacyVersion: privacyVersion);
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
        privacyVersion: privacyVersion);
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

  /// Records acceptance of the current notice, then kicks off the network
  /// work that was held back until consent. Updates state immediately and
  /// persists in the background.
  Future<void> acceptPrivacy() async {
    final data = state.value;
    if (data != null) {
      state = AsyncData(data.copyWith(privacyVersion: kPrivacyNoticeVersion));
    }
    unawaited(ref
        .read(settingsStoreProvider)
        .savePrivacyAcceptedVersion(kPrivacyNoticeVersion));
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
      // The exact instances this loop mutates: the fast republish below is
      // only valid while state still holds this very list.
      final target = data.accounts;
      var changed = false;
      for (final acc in target) {
        if (acc.steamId == 0) continue;
        var accChanged = false;
        var migratedLegacyPassword = false;
        // One-time migration: earlier builds stored the password in the keystore;
        // move it into the maFile so it travels with the account.
        if ((acc.password ?? '').isEmpty) {
          final legacy = await creds.password(acc.steamId);
          if (legacy != null && legacy.isNotEmpty) {
            acc.password = legacy;
            accChanged = true;
            migratedLegacyPassword = true;
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
          final saved = await data.store
              .saveAccount(acc, data.store.encrypted, passKey: data.passKey);
          changed = true;
          if (saved && migratedLegacyPassword) {
            // Drop the keystore copy now that the maFile owns the password.
            // Leaving it would resurrect a password the user later deletes
            // (login_screen sets account.password = null on opt-out, and
            // this migration would re-copy it on the next unlock).
            try {
              await creds.clear(acc.steamId);
            } catch (_) {
              // best-effort: a failed delete just retries next unlock
            }
          }
        }
      }
      if (changed && state.value != null) {
        if (!identical(state.value?.accounts, target)) {
          // A concurrent reload/unlock/import replaced the account list
          // mid-refresh: the renewed tokens live on the old instances (and
          // on disk), not on what state now holds — republishing that list
          // would keep the stale tokens on screen. Re-read disk instead.
          await reload();
        } else {
          // Republish the live objects under a new list identity instead of
          // a full disk re-read: everything above mutated these instances in
          // place and already persisted them via saveAccount, so re-reading
          // only re-decrypts what memory holds (and used to race the unlock
          // migration's file swap). Callers that truly need disk use
          // reload().
          state = AsyncData(state.value!.copyWith(accounts: [...target]));
        }
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
      // Same instance-tracking rationale as refreshSessions above.
      final target = data.accounts;
      final targets = [
        for (final acc in target)
          if (acc.steamId != 0 && (only == null || only.contains(acc.steamId)))
            acc,
      ];
      // Accounts refresh in parallel — each is 2–3 HTTP round-trips, and the
      // old sequential loop serialized ~3N of them behind the refresh
      // overlay. saveAccount stays safe: the store's write lock serializes
      // the actual disk mutations.
      final results = await Future.wait(
          [for (final acc in targets) _refreshOneAvatar(acc, svc, data)]);
      if (results.any((changed) => changed) && state.value != null) {
        if (!identical(state.value?.accounts, target)) {
          // Same concurrent-replacement hazard as refreshSessions above.
          await reload();
        } else {
          // Same republish-in-memory rationale as refreshSessions above.
          state = AsyncData(state.value!.copyWith(accounts: [...target]));
        }
      }
    } finally {
      _refreshingAvatars = false;
    }
  }

  /// Refreshes one account's avatar / persona / frame and persists it when
  /// something changed. Own catch: one account's network failure must not
  /// abort the rest of the batch (the old sequential loop died mid-way on
  /// the first throw, leaving later accounts stale).
  Future<bool> _refreshOneAvatar(
      SteamGuardAccount acc, AvatarService svc, AppData data) async {
    try {
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
        final refreshed = await SessionManager(ref.read(apiClientProvider))
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
      }
      return accChanged;
    } catch (e) {
      dlog('avatar refresh: ${acc.steamId} failed: $e');
      return false;
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

  /// The already-stored account this maFile would overwrite (same effective
  /// SteamID after normalization), or null when the import is new. Runs the
  /// same parse as [importMaFile], so alias-keyed / code-only files match too.
  /// [storedReadable] is false when only the manifest entry exists (the stored
  /// payload didn't decode) — then [account] is the parsed incoming file,
  /// good for a display name but not for merge decisions.
  /// Throws [MaFileImportException] for unusable input, same as the import.
  ({SteamGuardAccount account, bool storedReadable})? findImportCollision(
      String contents,
      {String? sourceName}) {
    final data = state.value;
    if (data == null) return null;
    final incoming =
        data.store.parseMaFileContents(contents, sourceName: sourceName);
    if (!data.store.entries.any((e) => e.steamId == incoming.steamId)) {
      return null;
    }
    for (final a in data.accounts) {
      if (a.steamId == incoming.steamId) {
        return (account: a, storedReadable: true);
      }
    }
    return (account: incoming, storedReadable: false);
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
    SteamGuardAccount? existing;
    final incomingId = data.store
        .parseMaFileContents(contents, sourceName: sourceName)
        .steamId;
    for (final a in data.accounts) {
      if (a.steamId == incomingId) {
        existing = a;
        break;
      }
    }
    final account = await data.store.importMaFileContents(
        contents, data.passKey,
        sourceName: sourceName, mergeExisting: existing);
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
    // Mirror the move in memory instead of reloading — a full reload decrypts
    // every account from disk and makes the dragged row visibly snap back.
    final accounts = [...data.accounts];
    final moved = accounts.removeAt(oldIndex);
    final insertAt = newIndex.clamp(0, accounts.length);
    accounts.insert(insertAt, moved);
    state = AsyncData(data.copyWith(accounts: accounts));
    // The manifest move must be keyed by steamId, not by these indices: the
    // visible list is the decryptable subset, so indices skew as soon as an
    // undecryptable entry precedes a decryptable one and an index-based move
    // would displace the wrong (invisible) entry.
    final beforeSteamId = insertAt + 1 < accounts.length
        ? accounts[insertAt + 1].steamId
        : null;
    final movedInManifest = await data.store
        .moveEntryById(moved.steamId, beforeSteamId: beforeSteamId);
    if (!movedInManifest) {
      // No manifest entry matches the dragged account's steamId (legacy
      // steamid-0 import, diverged entry): nothing was persisted, so resync
      // the optimistic in-memory order with disk instead of showing a
      // reorder that snaps back on the next restart.
      await reload();
      return;
    }
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

  /// Persists [account]'s renewed session onto the currently-loaded account.
  /// Unlike [persistAccount] it does not reload state or refetch avatars —
  /// nothing user-visible changed except the tokens. Safe to call from a
  /// pre-captured notifier after the calling widget unmounted: only the
  /// session is grafted onto the live instance, so a stale caller-held copy
  /// cannot clobber newer non-session fields (deleted password, re-import)
  /// already on disk. Best-effort: returns false when the store isn't loaded
  /// or the write failed.
  Future<bool> persistSession(SteamGuardAccount account) async {
    final data = state.value;
    if (data == null) return false;
    SteamGuardAccount? target;
    for (final a in data.accounts) {
      if (a.steamId == account.steamId) {
        target = a;
        break;
      }
    }
    // The account may have been removed while the caller's refresh was in
    // flight — saving the stale caller copy would re-insert the manifest
    // entry and resurrect the deleted account's secrets on disk.
    if (target == null) return false;
    if (!identical(target, account)) target.session = account.session;
    return data.store
        .saveAccount(target, data.store.encrypted, passKey: data.passKey);
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
