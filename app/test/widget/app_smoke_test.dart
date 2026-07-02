import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/app/app.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/privacy_consent_screen.dart';
import 'package:ava/src/ui/setup_pin_screen.dart';

void main() {
  testWidgets('first run gates on privacy consent, then mandatory PIN setup',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(MemoryStorageProvider()),
          // Avoid real network and periodic timers in the widget test.
          timeAlignerProvider.overrideWithValue(() async {}),
          tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
        ],
        child: const AvaApp(),
      ),
    );

    // The bootstrap reads a real settings file (dart:io), so let real async
    // I/O complete via runAsync, then pump to rebuild.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // First run: the Privacy Policy consent gate is shown before anything else.
    expect(find.byType(PrivacyConsentScreen), findsOneWidget);

    // Accept it (the single FilledButton). State updates synchronously.
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // A PIN is mandatory: an empty/unencrypted store then boots to PIN setup.
    expect(find.byType(SetupPinScreen), findsOneWidget);
  });
}
