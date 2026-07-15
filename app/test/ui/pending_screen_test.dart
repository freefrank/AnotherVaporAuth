import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/pending/pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// getlist 回空、GetTradeOffers 回空的 fake —— 冒烟只验证骨架渲染。
class _FakeApi extends SteamApiClient {
  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async =>
      {'success': true, 'conf': []};

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async =>
      {'response': {}};
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

void main() {
  testWidgets('pending screen renders both tabs and switches', (tester) async {
    final account = SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApi()),
        skinSpecProvider.overrideWith(_NoSkinSpec.new),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: PendingScreen(account: account),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Confirmations'), findsOneWidget);
    expect(find.text('Trade offers'), findsOneWidget);
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
  });
}
