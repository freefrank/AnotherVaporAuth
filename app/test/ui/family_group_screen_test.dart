import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/family_group_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override(provider 覆写基类)在 riverpod 3 移到了 misc 入口。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// GetFamilyGroup 返回「Wang 家」两成员组（family_groups_client_test 的
/// _groupResp 等价物），GetFamilyGroupForUser 返回空（非成员）。
/// miniProfile 走 communityGetJson 回空 —— 成员名退回 steamid64 字符串。
class _FakeApi extends SteamApiClient {
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GetFamilyGroup') {
      final m1 = ProtoWriter()
        ..writeFixed64(1, 76561198000000456)
        ..writeVarint(2, 1)
        ..writeVarint(3, 1752000000);
      final m2 = ProtoWriter()
        ..writeFixed64(1, 76561198000000123)
        ..writeVarint(2, 2)
        ..writeVarint(3, 1752100000);
      final w = ProtoWriter()
        ..writeString(1, 'Wang 家')
        ..writeMessage(2, m1)
        ..writeMessage(2, m2)
        ..writeVarint(4, 4) // free_spots
        ..writeString(5, 'CN')
        ..writeVarint(6, 3600);
      return ProtoReader(w.toBytes());
    }
    return ProtoReader(Uint8List(0)); // GetFamilyGroupForUser: 非成员
  }

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async =>
      {};
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

SteamGuardAccount _account() => SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );

Widget _app(SteamApiClient api, SteamGuardAccount account,
        {int? familyGroupId, List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        skinSpecProvider.overrideWith(_NoSkinSpec.new),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: FamilyGroupScreen(account: account, familyGroupId: familyGroupId),
      ),
    );

void main() {
  testWidgets('renders group name, members, and purchase-approval placeholder',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApi(), _account(), familyGroupId: 9001));
    await tester.pumpAndSettle();

    // 组名在 AppBar 标题。
    expect(find.text('Wang 家'), findsOneWidget);
    // 两行成员：miniProfile 回空 → steamid64 字符串;本账户带 (you) 后缀。
    expect(find.text('76561198000000456'), findsOneWidget);
    expect(find.text('76561198000000123 (you)'), findsOneWidget);
    expect(find.text('Adult'), findsOneWidget);
    expect(find.text('Child'), findsOneWidget);
    // 摘要:2 成员 + 4 空位 = 6 槽位。
    expect(find.text('Members 2/6'), findsOneWidget);
    // 购买审批占位。
    expect(find.text('Purchase approval is coming in a future update.'),
        findsOneWidget);
    // 只读页不呈现未实现的"退出家庭组"能力。
    expect(find.textContaining('Leave'), findsNothing);
    expect(find.textContaining('退出'), findsNothing);
  });

  testWidgets('null groupId + not a member shows the empty state',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApi(), _account()));
    await tester.pumpAndSettle();

    expect(find.text("This account isn't in a family group."), findsOneWidget);
    expect(find.text('Wang 家'), findsNothing);
  });
}
