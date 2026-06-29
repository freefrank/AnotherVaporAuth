import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../ui/home_screen.dart';
import '../ui/unlock_screen.dart';
import 'providers.dart';

class SdaApp extends ConsumerWidget {
  const SdaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    // Neutral Material 3 baseline; visual style is intentionally minimal and
    // will be themed later.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B2838), // Steam-ish navy placeholder
      brightness: Brightness.dark,
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const _Root(),
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
      data: (data) =>
          data.locked ? const UnlockScreen() : const HomeScreen(),
    );
  }
}
