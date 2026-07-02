import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/ui/tutorial.dart';

/// Pumps a minimal themed host with two spotlight targets and a button that
/// launches the tutorial route.
Future<void> _pumpHost(WidgetTester tester,
    {required LayerLink codeLink, required LayerLink rowLink}) {
  return tester.pumpWidget(MaterialApp(
    theme: buildSdaTheme(SdaThemeVariant.neon),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            CompositedTransformTarget(
                link: codeLink,
                child: const SizedBox(height: 40, width: 200)),
            CompositedTransformTarget(
                link: rowLink,
                child: const SizedBox(height: 60, width: 300)),
            ElevatedButton(
              onPressed: () => showGestureTutorial(context,
                  codeLink: codeLink, firstRowLink: rowLink),
              child: const Text('go'),
            ),
          ],
        ),
      ),
    ),
  ));
}

// The overlay hosts looping hint animations, so tests pump fixed durations
// instead of pumpAndSettle (which would never settle).
Future<void> _pumpSteps(WidgetTester tester, [int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('tutorial walks through all steps and completes',
      (tester) async {
    final codeLink = LayerLink();
    final rowLink = LayerLink();
    await _pumpHost(tester, codeLink: codeLink, rowLink: rowLink);

    await tester.tap(find.text('go'));
    await _pumpSteps(tester);
    expect(find.text('Live token'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Advance through the four remaining steps.
    for (final title in [
      'Swipe right → confirmations',
      'Swipe left → more actions',
      'Long-press → inventory & market',
      'Pull to refresh',
    ]) {
      await tester.tap(find.text('Next'));
      await _pumpSteps(tester);
      expect(find.text(title), findsOneWidget);
    }

    // Last step: no Skip, the primary button reads "Got it" and closes.
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Got it'));
    await _pumpSteps(tester);
    expect(find.text('Pull to refresh'), findsNothing);
  });

  testWidgets('tutorial can be skipped from the first step', (tester) async {
    final codeLink = LayerLink();
    final rowLink = LayerLink();
    await _pumpHost(tester, codeLink: codeLink, rowLink: rowLink);

    await tester.tap(find.text('go'));
    await _pumpSteps(tester);

    await tester.tap(find.text('Skip'));
    await _pumpSteps(tester);
    expect(find.text('Live token'), findsNothing);
  });

  testWidgets('tapping the scrim advances a step', (tester) async {
    final codeLink = LayerLink();
    final rowLink = LayerLink();
    await _pumpHost(tester, codeLink: codeLink, rowLink: rowLink);

    await tester.tap(find.text('go'));
    await _pumpSteps(tester);

    // Tap far from the card and the spotlight targets.
    await tester.tapAt(const Offset(20, 300));
    await _pumpSteps(tester);
    expect(find.text('Swipe right → confirmations'), findsOneWidget);
  });
}
