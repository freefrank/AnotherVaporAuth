import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../ui/home_screen.dart';
import '../ui/privacy_consent_screen.dart';
import '../ui/setup_pin_screen.dart';
import '../ui/unlock_screen.dart';
import '../ui/welcome_screen.dart';
import 'providers.dart';
import 'route_observer.dart';
import 'theme.dart';

class SdaApp extends ConsumerWidget {
  const SdaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final variant = ref.watch(themeVariantProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildSdaTheme(variant),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      builder: (context, child) => _Backdrop(child: child ?? const SizedBox()),
      home: const _Root(),
    );
  }
}

/// Paints the neon corner-gradient behind every screen (no-op in pixel theme).
class _Backdrop extends StatelessWidget {
  final Widget child;
  const _Backdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, gradient: t.bgGradient),
      child: child,
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
