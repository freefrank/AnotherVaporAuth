import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/entitlement_mint.dart';

class _NoApi implements EntitlementApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<String>.error(EntitlementApiException(0, 'network'));
}

void main() {
  final mint = EntitlementMint();
  final now = DateTime.utc(2026, 7, 15, 12);

  // NOTE: testWidgets runs under FakeAsync — real async file IO never
  // completes there, so everything below must stay synchronous (Sync temp
  // dirs, token seeding without touching SettingsStore).
  Widget app(Directory tmp, {String? storedToken}) {
    final storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(_NoApi()),
        entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
        clockProvider.overrideWithValue(() => now),
        if (storedToken != null)
          entitlementTokenProvider.overrideWith(() => _Seeded(storedToken)),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const PaywallScreen(),
      ),
    );
  }

  testWidgets('cn build renders Afdian unlock, beta card and free status',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.pumpWidget(app(tmp));
    await tester.pumpAndSettle();

    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('Unlock via Afdian'), findsOneWidget);
    expect(find.text('Open Afdian'), findsOneWidget);
    expect(find.text('Beta thank-you'), findsOneWidget);
    // The compile-time channel in tests is cn: no Play section.
    expect(find.text('Unlock via Google Play'), findsNothing);
    expect(find.text('No banner ads'), findsNothing);
  });

  testWidgets('pro status renders the entitlement end date', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // Noon UTC keeps the rendered local date stable across test-runner TZs.
    await tester.pumpWidget(app(tmp,
        storedToken:
            mint.mint(now: now, pro: DateTime.utc(2026, 8, 15, 12))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pro · until 2026-08-15'), findsOneWidget);
  });
}

/// Seeds a parsed token synchronously: no SettingsStore IO (would hang
/// under FakeAsync), no refresh timer.
class _Seeded extends EntitlementTokenController {
  final String raw;
  _Seeded(this.raw);

  @override
  EntitlementToken? build() => EntitlementToken.tryParse(raw,
      publicKey: ref.read(entitlementPublicKeyProvider));
}
