import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/l10n/app_localizations_en.dart';
import 'package:ava/l10n/app_localizations_zh.dart';
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
  // The future must carry the member's real type: a Future<String> handed to
  // an await of Future<EntitlementStatus> fails the implicit cast and leaves
  // the error future unlistened (= zone-level test failure).
  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.memberName ==
          #status
      ? Future<EntitlementStatus>.error(EntitlementApiException(0, 'network'))
      : Future<String>.error(EntitlementApiException(0, 'network'));
}

/// _NoApi plus a canned /v1/entitlement/status reply for the status card.
class _StatusApi extends _NoApi {
  final List<EntitlementActivation> activations;
  _StatusApi(this.activations);

  @override
  Future<EntitlementStatus> status(String token) async => EntitlementStatus(
      channel: 'beta', tier: 'pro', proUntil: 0, activations: activations);
}

void main() {
  final mint = EntitlementMint();
  final now = DateTime.utc(2026, 7, 15, 12);

  // NOTE: testWidgets runs under FakeAsync — real async file IO never
  // completes there, so everything below must stay synchronous (Sync temp
  // dirs, token seeding without touching SettingsStore).
  Widget app(Directory tmp, {String? storedToken, EntitlementApi? api}) {
    final storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api ?? _NoApi()),
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

  testWidgets('pro status card renders the activation classes', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.pumpWidget(app(tmp,
        storedToken: mint.mint(now: now, lifetime: true),
        api: _StatusApi([
          EntitlementActivation(
              deviceClass: 'android', activatedAt: DateTime.utc(2026, 7, 16)),
          EntitlementActivation(
              deviceClass: 'windows',
              activatedAt: DateTime.utc(2026, 7, 17),
              thisDevice: true),
        ])));
    await tester.pumpAndSettle();

    expect(find.text('Active on: Android · Windows (this device)'),
        findsOneWidget);
  });

  testWidgets('status fetch failure leaves the card without an activation row',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // _NoApi rejects every call, status() included.
    await tester.pumpWidget(
        app(tmp, storedToken: mint.mint(now: now, lifetime: true)));
    await tester.pumpAndSettle();

    expect(find.text('Pro · lifetime'), findsOneWidget);
    expect(find.textContaining('Active on:'), findsNothing);
  });

  group('paywallErrorText', () {
    final en = AppLocalizationsEn();

    // Everything the worker can emit today (logic.ts) plus ProActions' own
    // local codes; the launch-relevant subset must never render as the raw
    // proErrGeneric slug.
    const vocabulary = [
      'code_invalid',
      'code_redeemed',
      'code_activation_limit',
      'revoked',
      'entitlement_ended',
      'subscription_invalid',
      'order_invalid',
      'order_bound',
      'invalid_token',
      'no_vip',
      'not_earned',
      'bad_request',
      'internal',
    ];
    const launchRelevant = {
      'code_invalid',
      'code_redeemed',
      'code_activation_limit',
      'revoked',
      'entitlement_ended',
      'order_invalid',
      'order_bound',
      'no_vip',
      'not_earned',
    };

    test('no launch-relevant code falls to the generic slug', () {
      for (final code in vocabulary) {
        final text = paywallErrorText(en, code);
        expect(text, isNotEmpty, reason: code);
        if (launchRelevant.contains(code)) {
          expect(text, isNot(en.proErrGeneric(code)), reason: code);
        }
      }
    });

    test('beta-code refusals map to their dedicated copy', () {
      expect(paywallErrorText(en, 'code_invalid'), en.proErrCodeInvalid);
      // Legacy: only pre per-class-slot workers emit it, but during rollout
      // overlap it must keep its arm.
      expect(paywallErrorText(en, 'code_redeemed'), en.proErrCodeRedeemed);
      expect(paywallErrorText(en, 'code_activation_limit'),
          en.proErrCodeActivationLimit);
    });

    test('order_invalid (the code the worker actually emits) is not generic',
        () {
      expect(paywallErrorText(en, 'order_invalid'), en.proErrOrderNotFound);
    });
  });

  group('paywallActivationsLine', () {
    final acts = [
      EntitlementActivation(
          deviceClass: 'android', activatedAt: DateTime.utc(2026, 7, 16)),
      EntitlementActivation(
          deviceClass: 'windows',
          activatedAt: DateTime.utc(2026, 7, 17),
          thisDevice: true),
    ];

    test('joins class names and tags this device, per locale', () {
      expect(paywallActivationsLine(AppLocalizationsEn(), acts),
          'Active on: Android · Windows (this device)');
      expect(paywallActivationsLine(AppLocalizationsZh(), acts),
          '已激活：Android · Windows（本机）');
    });

    test('unknown class renders its raw slug rather than hiding the slot', () {
      expect(
          paywallActivationsLine(AppLocalizationsEn(), [
            EntitlementActivation(
                deviceClass: 'ios', activatedAt: DateTime.utc(2026, 7, 16)),
          ]),
          'Active on: ios');
    });
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
