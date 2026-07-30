import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../services/account_store.dart';
import 'screen_corners.dart';
import '../ui/home_screen.dart';
import '../ui/move_in_rescue_screen.dart';
import '../ui/privacy_consent_screen.dart';
import '../ui/setup_pin_screen.dart';
import '../ui/store_recovery_screen.dart';
import '../ui/unlock_screen.dart';
import '../ui/welcome_screen.dart';

import 'providers.dart';
import 'route_observer.dart';
import 'theme.dart';

class AvaApp extends ConsumerStatefulWidget {
  const AvaApp({super.key});

  @override
  ConsumerState<AvaApp> createState() => _AvaAppState();
}

class _AvaAppState extends ConsumerState<AvaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-resolve the theme when the OS light/dark setting flips (matters for
  // AvaBrightnessMode.system with no skin active).
  @override
  void didChangePlatformBrightness() => setState(() {});

  // Reconcile the launcher icon when leaving the app. Deferring the swap to
  // background (and startup) keeps it invisible — toggling launcher aliases
  // while foregrounded makes some launchers drop the task.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Launcher-icon switching is RETIRED as of 0.90.1. Every variant of
      // reconciling the alias at runtime (startup, paused, guarded by
      // loaded-state) ended the same way on ColorOS: changing the enabled
      // state of the alias the task was launched from makes the system
      // force-stop the app — including mid-fingerprint on the unlock screen,
      // which users experience as a launch crash-loop. The icon now simply
      // stays whatever alias is currently enabled. If the feature returns it
      // must use a mechanism that cannot toggle components while the app has
      // a foreground task (see docs/plans/2026-07-15-paywall-android.md).
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final textSize = ref.watch(textSizeProvider);
    final variant = resolveThemeVariant(
      // The effective skin, not the stored selection: neon/pixel fall back
      // to the plain look for free users (0.90 paywall).
      ref.watch(effectiveSkinProvider),
      ref.watch(brightnessModeProvider),
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAvaTheme(variant),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        // User text-size step stacks on the OS scaler (small = untouched).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
              textScaler: applyTextSize(mq.textScaler, textSize)),
          child: _SteamLanguageSync(
            // Publishes the display's corner radius to every screen below —
            // MediaQuery has no field for it, and it decides how far
            // bottom-edge content has to stay clear of the physical corner.
            child: ScreenCornersScope(
              child: _Backdrop(child: child ?? const SizedBox()),
            ),
          ),
        );
      },
      home: const _Root(),
    );
  }
}

/// Steam's own language slug for [locale]. These are Valve's names, not ISO
/// codes, so every locale AVA ships an ARB for needs an arm here — miss one
/// and that user reads the UI in their language while Steam-served strings
/// (item names, confirmation headlines) come back English.
///
/// Traditional Chinese must reach `tchinese`: falling through to `schinese`
/// would put Simplified item names inside an otherwise Traditional UI.
String steamLanguageFor(Locale locale) => switch (locale.languageCode) {
      'zh' => locale.scriptCode == 'Hant' ? 'tchinese' : 'schinese',
      'de' => 'german',
      'fr' => 'french',
      'es' => 'spanish',
      'ru' => 'russian',
      _ => 'english',
    };

/// Mirrors the resolved app locale onto [SteamApiClient.steamLanguage] so
/// Steam-served strings (confirmation headlines, item names) match the UI
/// language. Runs inside MaterialApp where Localizations is available.
class _SteamLanguageSync extends ConsumerWidget {
  final Widget child;
  const _SteamLanguageSync({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(apiClientProvider).steamLanguage =
        steamLanguageFor(Localizations.localeOf(context));
    return child;
  }
}

/// Paints the neon corner-gradient behind every screen (no-op in pixel theme).
class _Backdrop extends StatelessWidget {
  final Widget child;
  const _Backdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final dark = t.brightness == Brightness.dark;
    // Most screens have no AppBar, so pin the system icon brightness here
    // (dark status icons on the light theme, light icons everywhere else).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: t.brightness,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.bg, gradient: t.bgGradient),
        child: child,
      ),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return appState.when(
      // Riverpod 3 auto-retries a failed bootstrap with backoff; without this
      // flag every retry flips the UI back to the spinner and the error
      // screens below only ever flash between attempts.
      skipLoadingOnReload: true,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // A broken manifest gets the guided recovery screen; anything else a
      // readable error with a retry instead of a bare exception string.
      error: (e, _) => e is ManifestParseException
          ? const StoreRecoveryScreen()
          : _BootErrorScreen(error: e),
      data: (data) {
        // Move-in save failure: the rescue screen outranks every other gate —
        // it holds the only copies of a live authenticator's secrets and
        // needs no store access.
        final rescue = ref.watch(moveInRescueProvider);
        if (rescue != null) return MoveInRescueScreen(secrets: rescue);
        // First run: require accepting the Privacy Policy before anything else.
        if (!data.privacyAccepted) return const PrivacyConsentScreen();
        if (data.locked) return const UnlockScreen();
        // A PIN is mandatory: if the store isn't protected yet, set one first.
        if (!data.encrypted) return const SetupPinScreen();
        if (data.accounts.isEmpty) return const WelcomeScreen();
        return const HomeScreen();
      },
    );
  }
}

/// Fallback for bootstrap errors with no dedicated recovery path: the error
/// text stays selectable (so it can be reported) with a retry underneath.
class _BootErrorScreen extends ConsumerWidget {
  final Object error;
  const _BootErrorScreen({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(appControllerProvider),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
