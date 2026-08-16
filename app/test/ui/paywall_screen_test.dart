import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/l10n/app_localizations_en.dart';
import 'package:ava/l10n/app_localizations_zh.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/play_channel.dart';
import 'package:ava/src/services/pro_actions.dart';
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

/// Refuses redeemBeta with the worker's per-class-slot payload.
class _CappedApi extends _NoApi {
  @override
  Future<String> redeemBeta(
          {required String code,
          required String deviceId,
          required String deviceClass}) async =>
      throw EntitlementApiException(429, 'code_activation_limit',
          activations: [
            EntitlementActivation(
                deviceClass: 'android',
                activatedAt: DateTime.utc(2026, 7, 12)),
          ]);
}

/// _StatusApi whose redeemBeta hands out the given token — the happy
/// redeem-then-see-your-slot path. Counts status() calls so the redeem
/// (direct refresh + free→pro listener) is asserted to not double-fire it.
class _RedeemApi extends _StatusApi {
  final String token;
  int statusCalls = 0;
  _RedeemApi(this.token, super.activations);

  @override
  Future<EntitlementStatus> status(String tok) {
    statusCalls++;
    return super.status(tok);
  }

  @override
  Future<String> redeemBeta(
          {required String code,
          required String deviceId,
          required String deviceClass}) async =>
      token;
}

void main() {
  final mint = EntitlementMint();
  final now = DateTime.utc(2026, 7, 15, 12);

  // NOTE: testWidgets runs under FakeAsync — real async file IO never
  // completes there, so everything below must stay synchronous (Sync temp
  // dirs, token seeding without touching SettingsStore).
  Widget app(Directory tmp,
      {String? storedToken,
      EntitlementApi? api,
      EntitlementTokenController Function()? tokenController}) {
    final storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        entitlementApiProvider.overrideWithValue(api ?? _NoApi()),
        entitlementPublicKeyProvider.overrideWithValue(mint.publicKey),
        clockProvider.overrideWithValue(() => now),
        if (storedToken != null)
          entitlementTokenProvider.overrideWith(() => _Seeded(storedToken))
        else if (tokenController != null)
          entitlementTokenProvider.overrideWith(tokenController),
        // ProActions with no IO: deviceIdProvider's SettingsStore round-trip
        // would hang under FakeAsync.
        proActionsProvider.overrideWith((ref) => ProActions(
              api: ref.read(entitlementApiProvider),
              play: const PlayChannel(),
              deviceId: () async => 'device-1',
              adopt: (raw) =>
                  ref.read(entitlementTokenProvider.notifier).adopt(raw),
              deviceClass: 'android',
            )),
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

  testWidgets('code_activation_limit refusal names the occupied class + age',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.pumpWidget(app(tmp, api: _CappedApi()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'AVA-BETA-CAP');
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();

    // Not only the static "switched devices too often" copy: the occupied
    // slot (2026-07-12, three days before the frozen clock) is spelled out.
    expect(find.textContaining('In use: Android (3 days ago)'),
        findsOneWidget);
  });

  testWidgets('in-screen redeem surfaces the activation row without reopening',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('ava_paywall');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final api = _RedeemApi(mint.mint(now: now, lifetime: true), [
      EntitlementActivation(
          deviceClass: 'android',
          activatedAt: DateTime.utc(2026, 7, 15),
          thisDevice: true),
    ]);
    await tester.pumpWidget(
        app(tmp, api: api, tokenController: _NoIoController.new));
    await tester.pumpAndSettle();
    expect(find.text('Free plan'), findsOneWidget);
    expect(find.textContaining('Active on:'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'AVA-BETA-OK');
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();

    // The free→pro flip must re-trigger the (initState-time bailed)
    // activation fetch — no screen reopen required.
    expect(find.text('Pro · lifetime'), findsOneWidget);
    expect(find.text('Active on: Android (this device)'), findsOneWidget);
    // The direct on-success fetch and the free→pro listener must not both
    // fire status() — the initState bail (free) doesn't count.
    expect(api.statusCalls, 1);
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
      'rate_limited',
      'revoked',
      'entitlement_ended',
      'subscription_invalid',
      'order_invalid',
      'order_bound',
      'purchase_token_bound',
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
      'rate_limited',
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

    test('purchase_token_bound names the bound account when known', () {
      // The multi-account case this exists for: with a hint, the copy must
      // carry the masked address; without one it still gets dedicated copy,
      // never the generic slug.
      expect(paywallErrorText(en, 'purchase_token_bound', boundHint: 'a•••@gmail.com'),
          contains('a•••@gmail.com'));
      expect(paywallErrorText(en, 'purchase_token_bound'), en.proErrPurchaseBound);
      expect(paywallErrorText(en, 'purchase_token_bound'),
          isNot(en.proErrGeneric('purchase_token_bound')));
    });

    test('beta-code refusals map to their dedicated copy', () {
      expect(paywallErrorText(en, 'code_invalid'), en.proErrCodeInvalid);
      // Legacy: only pre per-class-slot workers emit it, but during rollout
      // overlap it must keep its arm.
      expect(paywallErrorText(en, 'code_redeemed'), en.proErrCodeRedeemed);
      expect(paywallErrorText(en, 'code_activation_limit'),
          en.proErrCodeActivationLimit);
      // The router's per-IP 429 — must read as "slow down", not as a bad code.
      expect(paywallErrorText(en, 'rate_limited'), en.proErrRateLimited);
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

  group('paywallSlotOccupiedLine', () {
    test('names the class with a relative age, per locale', () {
      final acts = [
        EntitlementActivation(
            deviceClass: 'android', activatedAt: DateTime.utc(2026, 7, 12)),
      ];
      expect(paywallSlotOccupiedLine(AppLocalizationsEn(), acts, now),
          'In use: Android (3 days ago)');
      expect(paywallSlotOccupiedLine(AppLocalizationsZh(), acts, now),
          '占用中：Android（3 天前）');
    });

    test('a same-day activation reads today, not 0 days ago', () {
      final acts = [
        EntitlementActivation(
            deviceClass: 'windows',
            activatedAt: DateTime.utc(2026, 7, 15, 8)),
      ];
      expect(paywallSlotOccupiedLine(AppLocalizationsEn(), acts, now),
          'In use: Windows (today)');
    });
  });
}

/// Starts empty and adopts without SettingsStore IO or refresh timers —
/// lets a redeem flip proStatus under FakeAsync.
class _NoIoController extends EntitlementTokenController {
  @override
  EntitlementToken? build() => null;

  @override
  Future<bool> adopt(String raw) async {
    final token = EntitlementToken.tryParse(raw,
        publicKey: ref.read(entitlementPublicKeyProvider));
    if (token == null) return false;
    state = token;
    return true;
  }
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
