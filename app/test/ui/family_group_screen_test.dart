import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/family_group_screen.dart';
import 'package:ava/src/ui/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override(provider 覆写基类)在 riverpod 3 移到了 misc 入口。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// 「Wang 家」两成员组的响应体(family_groups_client_test 的 _groupResp
/// 等价物;writer 形态,可整体嵌进 forUser 的字段 8)。
ProtoWriter _wangGroup() {
  final m1 = ProtoWriter()
    ..writeFixed64(1, 76561198000000456)
    ..writeVarint(2, 1)
    ..writeVarint(3, 1752000000);
  final m2 = ProtoWriter()
    ..writeFixed64(1, 76561198000000123)
    ..writeVarint(2, 2)
    ..writeVarint(3, 1752100000);
  return ProtoWriter()
    ..writeString(1, 'Wang 家')
    ..writeMessage(2, m1)
    ..writeMessage(2, m2)
    ..writeVarint(4, 4) // free_spots
    ..writeString(5, 'CN')
    ..writeVarint(6, 3600);
}

/// GetFamilyGroup 返回「Wang 家」两成员组，GetFamilyGroupForUser 返回空
/// （非成员）。miniProfile 走 communityGetJson 回空 —— 成员名退回
/// steamid64 字符串。
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
      return ProtoReader(_wangGroup().toBytes());
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

/// 成员路径:GetFamilyGroupForUser 已带回嵌套组(字段 8),
/// GetFamilyGroup 不应再被调用 —— 计数器证明短路生效。
class _FakeApiMemberNestedGroup extends SteamApiClient {
  int getFamilyGroupCalls = 0;

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
      getFamilyGroupCalls++;
      return ProtoReader(_wangGroup().toBytes());
    }
    if (method == 'GetFamilyGroupForUser') {
      final w = ProtoWriter()
        ..writeUint64(1, 9001) // family_groupid → 成员
        ..writeMessage(8, _wangGroup()); // include_family_group_response
      return ProtoReader(w.toBytes());
    }
    return ProtoReader(Uint8List(0));
  }

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async =>
      {};
}

/// GetFamilyGroupForUser returns one pending invite (non-member).
/// GetInviteCheckResults throws AccessDenied (ePrivilege=5 降级路径),
/// GetFamilyGroup throws Fail (通用标题路径), JoinFamilyGroup replies with
/// two_factor_method=1 so the join flow hands off to the confirmations screen.
class _FakeApiWithInvite extends SteamApiClient {
  int joinCalls = 0;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GetFamilyGroupForUser') {
      final invite = ProtoWriter()
        ..writeUint64(1, 9001) // family_groupid
        ..writeVarint(2, 1) // role
        ..writeFixed64(3, 76561198000000456) // inviter_steamid (fixed64!)
        ..writeBool(4, false) // awaiting_2fa
        ..writeUint64(5, 555001); // invite_id
      final w = ProtoWriter()
        ..writeBool(2, true) // is_not_member_of_any_group
        ..writeMessage(5, invite);
      return ProtoReader(w.toBytes());
    }
    if (method == 'GetInviteCheckResults') {
      throw SteamApiException(15, 'denied', 'GetInviteCheckResults');
    }
    if (method == 'GetFamilyGroup') {
      throw SteamApiException(2, 'fail', 'GetFamilyGroup');
    }
    if (method == 'JoinFamilyGroup') {
      joinCalls++;
      final w = ProtoWriter()..writeVarint(2, 1); // two_factor_method=1
      return ProtoReader(w.toBytes());
    }
    return ProtoReader(Uint8List(0));
  }

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

/// [_FakeApiWithInvite] variant whose preflight succeeds but reports a wallet
/// country mismatch — the join button must come out disabled (spec 承诺).
class _FakeApiWalletMismatch extends _FakeApiWithInvite {
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GetInviteCheckResults') {
      final w = ProtoWriter()
        ..writeBool(1, false) // wallet_country_matches
        ..writeBool(2, true) // ip_match
        ..writeVarint(3, 0); // join_restriction
      return ProtoReader(w.toBytes());
    }
    return super.callProtobuf(iface, method,
        request: request,
        accessToken: accessToken,
        useGet: useGet,
        version: version);
  }
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
    // 摘要:2 成员 + 4 空位 = 6 槽位;3600s 冷却上取整为 1 天。
    expect(find.text('Members 2/6'), findsOneWidget);
    expect(find.text('Cooldown 1d'), findsOneWidget);
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

  testWidgets(
      'null groupId member path uses the nested field-8 group without '
      'calling GetFamilyGroup', (tester) async {
    final api = _FakeApiMemberNestedGroup();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();

    expect(find.text('Wang 家'), findsOneWidget);
    expect(api.getFamilyGroupCalls, 0,
        reason: 'the field-8 group must short-circuit the GetFamilyGroup '
            'follow-up call');
  });

  // Invites moved here from the old todo-center tab: the long-press entry
  // (familyGroupId == null) surfaces pending invites for a non-member.
  testWidgets('pending invite renders degraded with a generic title',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApiWithInvite(), _account()));
    await tester.pumpAndSettle();

    // GetFamilyGroup 失败 → 通用标题;GetInviteCheckResults 拒绝 → 降级。
    expect(find.text('Family group invite'), findsOneWidget);
    expect(find.text('Hold to join'), findsOneWidget);
    // 静态冷却警告不依赖预检端点,始终显示。
    expect(find.textContaining('Joining locks family-group switching'),
        findsOneWidget);
    // 降级生效:钱包/IP 预检行都不出现。
    expect(find.textContaining('Wallet region'), findsNothing);
    expect(find.text('✓ Usual IP matches'), findsNothing);
  });

  testWidgets('wallet country mismatch disables the join button',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApiWalletMismatch(), _account()));
    await tester.pumpAndSettle();

    expect(find.textContaining("Wallet region doesn't match"), findsOneWidget);
    expect(
        tester
            .widget<HoldToConfirmButton>(find.byType(HoldToConfirmButton))
            .enabled,
        isFalse,
        reason: 'a wallet-region mismatch must disable the join button');
  });

  testWidgets('hold-to-join sends the join and opens the todo center',
      (tester) async {
    final api = _FakeApiWithInvite();
    await tester.pumpWidget(_app(api, _account()));
    await tester.pumpAndSettle();

    // Drive the 900ms hold past completion.
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Hold to join')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(api.joinCalls, 1);
    // A 2FA-needed join pushes the todo center (PendingScreen) so the user can
    // approve the mobile confirmation — its tabs are now on screen.
    expect(find.text('Confirmations'), findsOneWidget);
    expect(find.text('Trade offers'), findsOneWidget);
  });
}
