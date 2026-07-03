import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../ui/home_screen.dart';
import '../ui/privacy_consent_screen.dart';
import '../ui/setup_pin_screen.dart';
import '../ui/unlock_screen.dart';
import '../ui/welcome_screen.dart';
import '../services/launcher_icon.dart';
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
      LauncherIcon.apply(ref.read(skinProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final variant = resolveThemeVariant(
      ref.watch(skinProvider),
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
      builder: (context, child) => _SteamLanguageSync(
        child: _Backdrop(child: child ?? const SizedBox()),
      ),
      home: const _Root(),
    );
  }
}

/// Mirrors the resolved app locale onto [SteamApiClient.steamLanguage] so
/// Steam-served strings (confirmation headlines, item names) match the UI
/// language. Runs inside MaterialApp where Localizations is available.
class _SteamLanguageSync extends ConsumerWidget {
  final Widget child;
  const _SteamLanguageSync({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = Localizations.localeOf(context).languageCode;
    ref.read(apiClientProvider).steamLanguage =
        code == 'zh' ? 'schinese' : 'english';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (data) {
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
