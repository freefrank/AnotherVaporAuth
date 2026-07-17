import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/app/app.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/privacy_consent_screen.dart';
import 'package:ava/src/ui/setup_pin_screen.dart';
import 'package:ava/src/ui/store_recovery_screen.dart';

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

  testWidgets(
      'corrupt manifest boots to the recovery screen; reset yields a clean '
      'store', (tester) async {
    final storage = MemoryStorageProvider();
    // Garbage manifest: AccountStore.load throws ManifestParseException
    // (files non-empty ⇒ dirExists true, so this is not a clean first run).
    storage.files['manifest.json'] = 'not json';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          timeAlignerProvider.overrideWithValue(() async {}),
          tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
        ],
        child: const AvaApp(),
      ),
    );
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The typed recovery screen, not a bare exception string.
    expect(find.byType(StoreRecoveryScreen), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('manifest'), findsOneWidget);
    expect(find.text('ManifestParseException'), findsNothing);

    // Escape hatch opens the same confirm dialog as the unlock screen.
    await tester.tap(find.text('Reset encrypted data'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Delete & reset'));
    // Reset + re-bootstrap interleave fake-zone microtasks with real IO
    // (settings file, key clears) — alternate pumps and real-async waits
    // until the root has swapped off the recovery screen.
    for (var i = 0;
        i < 10 && find.byType(StoreRecoveryScreen).evaluate().isNotEmpty;
        i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }

    // A clean, unlocked, empty store was committed and the app rebooted off
    // the recovery screen (which gate shows depends on persisted settings).
    expect(find.byType(StoreRecoveryScreen), findsNothing);
    final m = Manifest.fromJson(
        jsonDecode(storage.files['manifest.json']!) as Map<String, dynamic>);
    expect(m.vault, isFalse);
    expect(m.encrypted, isFalse);
    expect(m.entries, isEmpty);
  });
}
