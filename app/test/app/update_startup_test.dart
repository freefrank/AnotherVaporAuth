import 'dart:async';

import 'package:ava/src/app/app.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/core/update_check.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/update_service.dart';
import 'package:ava/src/ui/privacy_consent_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A settings store whose update-check switch is off, everything else stock.
class _UpdateCheckOffSettings extends SettingsStore {
  _UpdateCheckOffSettings(super.storage);
  @override
  Future<bool> loadUpdateCheckEnabled() async => false;
}

/// An update service whose check never completes — the worst network there is.
class _HangingUpdateService implements UpdateService {
  int calls = 0;

  @override
  Future<UpdateDecision> check({
    required String currentVersion,
    required String channelKey,
  }) {
    calls++;
    return Completer<UpdateDecision>().future;
  }
}

void main() {
  testWidgets(
      'startup renders even when the update check hangs forever — '
      'the offline-launch promise', (tester) async {
    final hanging = _HangingUpdateService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(MemoryStorageProvider()),
          timeAlignerProvider.overrideWithValue(() async {}),
          tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
          // PackageInfo's platform channel does not exist under flutter_test.
          appVersionProvider.overrideWith((ref) async => '1.2.0'),
          updateServiceProvider.overrideWithValue(hanging),
        ],
        child: const AvaApp(),
      ),
    );

    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // First-run UI is on screen: the app booted to its normal first gate
    // while the check is still pending, i.e. nothing on the startup path
    // awaited it. If someone ever chains startup behind the check, this
    // renders a spinner instead and fails.
    expect(find.byType(PrivacyConsentScreen), findsOneWidget);
    expect(hanging.calls, 1,
        reason: 'the post-frame hook must actually have fired the check');
  });

  testWidgets('the check never runs when the setting is off', (tester) async {
    final hanging = _HangingUpdateService();
    final storage = MemoryStorageProvider();
    // Overriding the store, not writing a file first: SettingsStore does real
    // dart:io under MemoryStorageProvider's fake path, so a pre-boot write
    // lands nowhere — and anything after pumpWidget races the post-frame hook.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          settingsStoreProvider
              .overrideWithValue(_UpdateCheckOffSettings(storage)),
          timeAlignerProvider.overrideWithValue(() async {}),
          tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
          appVersionProvider.overrideWith((ref) async => '1.2.0'),
          updateServiceProvider.overrideWithValue(hanging),
        ],
        child: const AvaApp(),
      ),
    );
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(hanging.calls, 0,
        reason: 'the off switch must gate the request itself, not just the UI');
  });
}
