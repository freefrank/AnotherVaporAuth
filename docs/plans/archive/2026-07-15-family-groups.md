# 家庭组（邀请页签 + 信息页） 实施计划（计划 2/2）

> **已归档(2026-07-18)**:功能已随 **v0.82.0**(2026-07-15)发布并在后续版本迭代
> (0.91.0 起接口错误显示简短原因)。计划内复选框当时未逐项勾选,以 CHANGELOG
> 与代码现状为准。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 待办中心新增"邀请"第三页签（发现家庭组邀请、加入前预检、长按加入、与 type-11 mobileconf 确认联动），加一个只读的家庭组信息页。

**Architecture:** 新增 `FamilyGroupsClient`（`IFamilyGroupsService` protobuf 调用，字段号取自 SteamDatabase webui dump，逐字核对过）+ 纯 Dart 模型；`FamilyInvitesTab` 完整镜像 `TradeOffersTab` 的骨架（keep-alive、防重入 refresh、SessionManager 自动续期、needs-login、onCount 角标、设置开关透传）；`FamilyGroupScreen` 只读信息页从账户菜单与已加入卡进入。

**Tech Stack:** Flutter 3.44.x / Dart 3.12，Riverpod，手写 protobuf wire（`protobuf_wire.dart`），flutter_test。无新增依赖。

**基线**：分支 `feat/family-groups`（基点 `d4d62ac`，v0.81.0，234 测试全绿）。

**每个 commit 末尾 trailer（CLAUDE.md 约定）：**

```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823
```

**验证命令**（每个 Task 收尾必跑）：`cd app && flutter analyze && flutter test`

---

## 协议事实（侦察结论，字段号逐字核对自 `webui/service_familygroups.proto`）

| RPC（URL 均为 `IFamilyGroupsService/<Method>`） | 请求字段 | 响应字段 |
|---|---|---|
| `GetFamilyGroupForUser` | 1 `steamid` **uint64 varint**（不是 fixed64！）、2 `include_family_group_response` bool | 1 `family_groupid` u64、2 `is_not_member_of_any_group` bool、5 **repeated** `FamilyGroupPendingInviteForUser`（嵌套消息）、6 `role` u32、7 `cooldown_seconds_remaining` u32、8 嵌套 `GetFamilyGroup_Response` |
| `GetFamilyGroup` | 1 `family_groupid` varint | 1 `name` string、2 **repeated** `FamilyGroupMember`、4 `free_spots` u32、5 `country` string、6 `slot_cooldown_remaining_seconds` u32 |
| `GetInviteCheckResults` | 1 `family_groupid` varint、2 `steamid` **fixed64** | 1 `wallet_country_matches` bool、2 `ip_match` bool、3 `join_restriction` u32 |
| `JoinFamilyGroup` | 1 `family_groupid` varint、2 `nonce` **uint64 varint** | **无字段 1**！2 `two_factor_method` int32、3 `cooldown_skip_granted`、4 `invite_already_accepted`、5 `cooldown_seconds_remaining` |
| `ConfirmJoinFamilyGroup` | 1 `family_groupid`、2 `invite_id`、3 `nonce`（均 varint） | 空响应（成功看 eresult） |

嵌套消息：
- `FamilyGroupPendingInviteForUser`：1 `family_groupid` u64 varint、2 `role` int32、3 `inviter_steamid` **fixed64**、4 `awaiting_2fa` bool、5 `invite_id` u64 varint
- `FamilyGroupMember`：1 `steamid` **fixed64**、2 `role` int32、3 `time_joined` u32

> 上表是 **AVA 使用的字段子集**。proto 中还有本计划有意忽略的字段（解析 switch 直接跳过）：
> `FamilyGroupMember.4 cooldown_seconds_remaining`、`GetFamilyGroup` 响应 3（pending_invites）/7（former_members）/8（slot_cooldown_overrides）、
> `GetFamilyGroupForUser` 响应 3/4/9/10。新增解析时先查原始 proto，勿复用这些字段号做别的用途。

**已知不确定性（设计已按此定型）：**
1. `GetInviteCheckResults` 标注 **ePrivilege=5**（内部权限）——普通用户 token 可能被拒。预检必须**优雅降级**：调用失败 → 隐藏动态预检行，只保留静态冷却警告；不阻塞加入。
2. **邀请消息没有 nonce 字段**。`join` 以 `invite_id` 充当 nonce（最佳候选），真机验证；失败时 eresult 错误会透出给用户。
3. `role` 枚举无权威定义（webui dump 扁平化为 int32）。按社区共识映射 1→成人、2→儿童，其他显示 `#n`；真机核对。
4. `ConfirmJoinFamilyGroup` 是否必调未知——client 实现该方法，v1 UI 流程**不调用**（预期 type-11 mobileconf 接受即完成加入），真机联调决定是否接线。

**对 spec 的收窄（本计划显式记录，实现后写入执行后记）：**
- 邀请卡**不做"谢绝"**：收件人侧的 decline RPC 未在 proto 中确认，不猜端点。
- 信息页摘要**去掉"共享游戏数"**：`GetFamilyGroup` 响应没有该数据（`GetSharedLibraryApps` 是另一 RPC，超范围）。摘要 = 成员 n/m + 冷却。
- 账户菜单的"家庭组"入口**始终显示**（菜单同步构建，无法预知成员身份）；非成员时信息页显示空态。
- **"卡片变为已加入 ✓"需要手动刷新触发**（下拉或刷新按钮）：邀请页签 keep-alive，从确认页签接受 type-11 后返回不会自动重拉——与报价页签同构（自动刷新会破坏 keep-alive 语义与测试）。邀请角标同样懒加载（首次访问页签时才拉取），继承计划 1 报价页签的既有行为。

**全计划实现注意**：计划代码中的 `!` 非空断言若被 analyze 判为 unnecessary（流程已提升为非空），以 analyze 为准删除——零问题门槛优先于计划字面。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `app/lib/src/core/models/family_group.dart`（新） | `FamilyInvite` / `FamilyMember` / `FamilyGroupInfo` / `FamilyUserState` / `InviteChecks` / `JoinResult` 纯模型 |
| `app/lib/src/core/protocol/family_groups_client.dart`（新） | 5 个 RPC 的编解码 + 模型构造 |
| `app/lib/src/app/providers.dart`（改） | `familyGroupsClientProvider` |
| `app/lib/src/ui/pending/family_invites_tab.dart`（新） | 邀请页签 |
| `app/lib/src/ui/pending/pending_screen.dart`（改） | 第三页签接线 |
| `app/lib/src/ui/family_group_screen.dart`（新） | 只读信息页 |
| `app/lib/src/ui/home_screen.dart`（改） | 账户菜单"家庭组"入口 |
| `app/lib/l10n/app_en.arb`、`app_zh.arb`（改） | `fam*` 字符串 |
| `app/test/core/family_groups_client_test.dart`（新） | 协议编解码测试（callProtobuf fake + ProtoWriter 构造响应） |
| `app/test/ui/pending_screen_test.dart`（改） | 基础 fake 补 `callProtobuf` override + 邀请页签用例 |
| `app/test/ui/family_group_screen_test.dart`（新） | 信息页冒烟 |

---

### Task 1: 家庭组模型（纯 Dart）

**Files:**
- Create: `app/lib/src/core/models/family_group.dart`

无独立测试（纯数据类，构造与字段由 Task 2 的 client 测试全覆盖）。

- [ ] **Step 1: 实现**

```dart
// app/lib/src/core/models/family_group.dart

/// A pending family-group invite for this account
/// (FamilyGroupPendingInviteForUser).
class FamilyInvite {
  final int familyGroupId;
  final int role; // opaque Steam role id; see [familyRoleLabelKey]
  final int inviterSteamId; // steamid64
  final bool awaiting2fa;
  final int inviteId;

  const FamilyInvite({
    required this.familyGroupId,
    required this.role,
    required this.inviterSteamId,
    required this.awaiting2fa,
    required this.inviteId,
  });
}

/// One member of a family group (FamilyGroupMember).
class FamilyMember {
  final int steamId; // steamid64
  final int role;
  final int timeJoined;

  const FamilyMember({
    required this.steamId,
    required this.role,
    required this.timeJoined,
  });
}

/// Read-only snapshot of a family group (CFamilyGroups_GetFamilyGroup_Response).
class FamilyGroupInfo {
  final String name;
  final List<FamilyMember> members;
  final int freeSpots;
  final String country;
  final int slotCooldownRemainingSeconds;

  const FamilyGroupInfo({
    required this.name,
    required this.members,
    required this.freeSpots,
    required this.country,
    required this.slotCooldownRemainingSeconds,
  });

  int get totalSlots => members.length + freeSpots;
}

/// This account's family situation (GetFamilyGroupForUser).
class FamilyUserState {
  final int familyGroupId; // 0 when not a member
  final bool isNotMemberOfAnyGroup;
  final List<FamilyInvite> pendingInvites;
  final int role;
  final int cooldownSecondsRemaining;
  final FamilyGroupInfo? group; // set when include_family_group_response

  const FamilyUserState({
    required this.familyGroupId,
    required this.isNotMemberOfAnyGroup,
    required this.pendingInvites,
    required this.role,
    required this.cooldownSecondsRemaining,
    this.group,
  });

  bool get isMember => !isNotMemberOfAnyGroup && familyGroupId != 0;
}

/// Pre-join checks (GetInviteCheckResults). The endpoint is marked
/// ePrivilege=5 in Valve's dump — it may be refused for ordinary user
/// tokens, so callers treat "unavailable" (null) as a first-class state.
class InviteChecks {
  final bool walletCountryMatches;
  final bool ipMatch;
  final int joinRestriction; // 0 = no restriction

  const InviteChecks({
    required this.walletCountryMatches,
    required this.ipMatch,
    required this.joinRestriction,
  });
}

/// Result of JoinFamilyGroup. two_factor_method != 0 means Steam expects a
/// 2FA confirmation (the type-11 mobileconf this app can accept).
class JoinResult {
  final int twoFactorMethod;
  final bool cooldownSkipGranted;
  final bool inviteAlreadyAccepted;
  final int cooldownSecondsRemaining;

  const JoinResult({
    required this.twoFactorMethod,
    required this.cooldownSkipGranted,
    required this.inviteAlreadyAccepted,
    required this.cooldownSecondsRemaining,
  });

  bool get needsTwoFactor => twoFactorMethod != 0;
}
```

- [ ] **Step 2: 验证 + Commit**

Run: `cd app && flutter analyze && flutter test` — 零问题全绿。

```bash
git add app/lib/src/core/models/family_group.dart
git commit -m "feat(family): family group data models

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 2: FamilyGroupsClient（协议编解码，TDD）

**Files:**
- Create: `app/lib/src/core/protocol/family_groups_client.dart`
- Test: `app/test/core/family_groups_client_test.dart`

- [ ] **Step 1: 写失败测试**（fake 模式照抄 `qr_approval_client_test.dart:13-32`；响应体用 ProtoWriter 构造，覆盖：repeated 嵌套邀请、fixed64 steamid、字段号正确性、无 token 前置抛错、预检降级、Join 响应从字段 2 开始）

```dart
// app/test/core/family_groups_client_test.dart
import 'dart:typed_data';

import 'package:ava/src/core/models/family_group.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/family_groups_client.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart'
    show MissingAccessTokenException;
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
  final Object? throwOnCall;
  String? lastMethod;
  ProtoWriter? lastRequest;
  String? lastAccessToken;
  _FakeApi(this.responses, {this.throwOnCall});

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    lastMethod = '$iface/$method';
    lastRequest = request;
    lastAccessToken = accessToken;
    if (throwOnCall != null) throw throwOnCall!;
    return responses.removeAt(0);
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
      accountName: 'acc',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 'tok', refreshToken: 'r'),
    );

/// 构造 GetFamilyGroupForUser 响应：两条邀请 + 非成员标记。
ProtoReader _forUserResp() {
  final invite1 = ProtoWriter()
    ..writeUint64(1, 9001) // family_groupid
    ..writeVarint(2, 1) // role
    ..writeFixed64(3, 76561198000000456) // inviter_steamid (fixed64!)
    ..writeBool(4, false) // awaiting_2fa
    ..writeUint64(5, 555001); // invite_id
  final invite2 = ProtoWriter()
    ..writeUint64(1, 9002)
    ..writeVarint(2, 2)
    ..writeFixed64(3, 76561198000000789)
    ..writeBool(4, true)
    ..writeUint64(5, 555002);
  final w = ProtoWriter()
    ..writeBool(2, true) // is_not_member_of_any_group
    ..writeMessage(5, invite1)
    ..writeMessage(5, invite2);
  return ProtoReader(w.toBytes());
}

/// 构造 GetFamilyGroup 响应：组名 + 两个成员 + 空位。
ProtoReader _groupResp() {
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

void main() {
  group('forUser', () {
    test('parses repeated nested invites incl. fixed64 inviter', () async {
      final api = _FakeApi([_forUserResp()]);
      final s = await FamilyGroupsClient(api).forUser(_account());
      expect(api.lastMethod, 'IFamilyGroupsService/GetFamilyGroupForUser');
      expect(api.lastAccessToken, 'tok');
      expect(s.isNotMemberOfAnyGroup, isTrue);
      expect(s.isMember, isFalse);
      expect(s.pendingInvites, hasLength(2));
      final i = s.pendingInvites.first;
      expect(i.familyGroupId, 9001);
      expect(i.role, 1);
      expect(i.inviterSteamId, 76561198000000456);
      expect(i.awaiting2fa, isFalse);
      expect(i.inviteId, 555001);
      expect(s.pendingInvites[1].awaiting2fa, isTrue);
      // 请求编码：steamid 是字段 1 的 varint（uint64，非 fixed64）。
      final req = ProtoReader(api.lastRequest!.toBytes()).parse();
      expect(req[1]?.varint, 76561198000000123);
      expect(req[2]?.asBool, isTrue); // include_family_group_response
    });

    test('missing access token throws before any call', () async {
      final api = _FakeApi([]);
      final noToken = SteamGuardAccount(
          session: SessionData(steamId: 1, refreshToken: 'r'));
      expect(() => FamilyGroupsClient(api).forUser(noToken),
          throwsA(isA<MissingAccessTokenException>()));
      expect(api.lastMethod, isNull);
    });
  });

  test('groupInfo parses name/members/slots', () async {
    final api = _FakeApi([_groupResp()]);
    final g = await FamilyGroupsClient(api).groupInfo(_account(), 9001);
    expect(api.lastMethod, 'IFamilyGroupsService/GetFamilyGroup');
    expect(g.name, 'Wang 家');
    expect(g.members, hasLength(2));
    expect(g.members.first.steamId, 76561198000000456);
    expect(g.members.first.role, 1);
    expect(g.freeSpots, 4);
    expect(g.totalSlots, 6);
    expect(g.country, 'CN');
    // 请求编码：family_groupid varint 字段 1。
    final req = ProtoReader(api.lastRequest!.toBytes()).parse();
    expect(req[1]?.varint, 9001);
  });

  group('inviteChecks (ePrivilege=5 degradation)', () {
    test('parses checks and encodes fixed64 steamid at field 2', () async {
      final w = ProtoWriter()
        ..writeBool(1, true)
        ..writeBool(2, false)
        ..writeVarint(3, 0);
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final c = await FamilyGroupsClient(api).inviteChecks(_account(), 9001);
      expect(c, isNotNull);
      expect(c!.walletCountryMatches, isTrue);
      expect(c.ipMatch, isFalse);
      expect(c.joinRestriction, 0);
      final req = ProtoReader(api.lastRequest!.toBytes()).parse();
      expect(req[1]?.varint, 9001);
      expect(req[2]?.asFixed64, 76561198000000123); // fixed64!
    });

    test('SteamApiException degrades to null (endpoint may be internal)',
        () async {
      final api = _FakeApi([],
          throwOnCall: SteamApiException(15 /* AccessDenied */, 'denied',
              'GetInviteCheckResults'));
      expect(await FamilyGroupsClient(api).inviteChecks(_account(), 9001),
          isNull);
    });
  });

  group('join', () {
    test('encodes groupid+nonce, parses response starting at field 2',
        () async {
      final w = ProtoWriter()
        ..writeVarint(2, 1) // two_factor_method
        ..writeBool(4, false); // invite_already_accepted
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final invite = FamilyInvite(
          familyGroupId: 9001,
          role: 1,
          inviterSteamId: 1,
          awaiting2fa: false,
          inviteId: 555001);
      final r = await FamilyGroupsClient(api).join(_account(), invite);
      expect(api.lastMethod, 'IFamilyGroupsService/JoinFamilyGroup');
      expect(r.needsTwoFactor, isTrue);
      expect(r.inviteAlreadyAccepted, isFalse);
      final req = ProtoReader(api.lastRequest!.toBytes()).parse();
      expect(req[1]?.varint, 9001);
      expect(req[2]?.varint, 555001); // nonce = invite_id（最佳候选，真机验证）
    });

    test('empty response body means no-2fa join', () async {
      final api = _FakeApi([ProtoReader(Uint8List(0))]);
      final invite = FamilyInvite(
          familyGroupId: 9001,
          role: 1,
          inviterSteamId: 1,
          awaiting2fa: false,
          inviteId: 555001);
      final r = await FamilyGroupsClient(api).join(_account(), invite);
      expect(r.needsTwoFactor, isFalse);
    });
  });

  test('confirmJoin encodes all three ids; empty response is success',
      () async {
    final api = _FakeApi([ProtoReader(Uint8List(0))]);
    await FamilyGroupsClient(api)
        .confirmJoin(_account(), familyGroupId: 9001, inviteId: 555001);
    expect(api.lastMethod, 'IFamilyGroupsService/ConfirmJoinFamilyGroup');
    final req = ProtoReader(api.lastRequest!.toBytes()).parse();
    expect(req[1]?.varint, 9001);
    expect(req[2]?.varint, 555001);
    expect(req[3]?.varint, 555001); // nonce = invite_id
  });
}
```

- [ ] **Step 2: 跑测试确认失败** — `cd app && flutter test test/core/family_groups_client_test.dart` → FAIL。

- [ ] **Step 3: 实现 client**

```dart
// app/lib/src/core/protocol/family_groups_client.dart
import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/family_group.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';
import 'qr_approval_client.dart' show MissingAccessTokenException;

/// Steam Family Groups (`IFamilyGroupsService`, webui protobuf surface).
/// Field numbers follow SteamDatabase/Protobufs webui/service_familygroups.proto
/// — verbatim-checked; see the plan's 协议事实 table. All calls authenticate
/// with the account's access token.
class FamilyGroupsClient {
  final SteamApiClient api;
  FamilyGroupsClient(this.api);

  String _requireToken(SteamGuardAccount account) {
    final token = account.session.accessToken;
    if (token == null || token.isEmpty) {
      throw const MissingAccessTokenException();
    }
    return token;
  }

  /// This account's family situation: current group + pending invites.
  Future<FamilyUserState> forUser(SteamGuardAccount account) async {
    final token = _requireToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, account.steamId) // steamid (uint64 varint, NOT fixed64)
      ..writeBool(2, true); // include_family_group_response
    final reader = await api.callProtobuf(
      'IFamilyGroupsService',
      'GetFamilyGroupForUser',
      request: req,
      accessToken: token,
    );
    final invites = <FamilyInvite>[];
    var familyGroupId = 0;
    var notMember = false;
    var role = 0;
    var cooldown = 0;
    FamilyGroupInfo? group;
    for (final f in reader.parseAll()) {
      switch (f.number) {
        case 1:
          familyGroupId = f.asInt;
        case 2:
          notMember = f.asBool;
        case 5: // repeated FamilyGroupPendingInviteForUser
          if (f.bytes != null) invites.add(_invite(f.bytes!));
        case 6:
          role = f.asInt;
        case 7:
          cooldown = f.asInt;
        case 8: // nested CFamilyGroups_GetFamilyGroup_Response
          if (f.bytes != null) group = _group(f.bytes!);
      }
    }
    dlog('family forUser: member=${!notMember} groupId=$familyGroupId '
        'invites=${invites.length}');
    return FamilyUserState(
      familyGroupId: familyGroupId,
      isNotMemberOfAnyGroup: notMember,
      pendingInvites: invites,
      role: role,
      cooldownSecondsRemaining: cooldown,
      group: group,
    );
  }

  /// Read-only group snapshot (name, members, slots, cooldown).
  Future<FamilyGroupInfo> groupInfo(
      SteamGuardAccount account, int familyGroupId) async {
    final token = _requireToken(account);
    final req = ProtoWriter()..writeUint64(1, familyGroupId);
    final reader = await api.callProtobuf(
      'IFamilyGroupsService',
      'GetFamilyGroup',
      request: req,
      accessToken: token,
    );
    return _groupFromReader(reader);
  }

  /// Pre-join checks. Valve marks this endpoint ePrivilege=5 (internal), so a
  /// plain user token may be refused — any [SteamApiException] degrades to
  /// null and the UI simply hides the dynamic check rows.
  Future<InviteChecks?> inviteChecks(
      SteamGuardAccount account, int familyGroupId) async {
    final token = _requireToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, familyGroupId)
      ..writeFixed64(2, account.steamId); // steamid (fixed64 here!)
    try {
      final fields = (await api.callProtobuf(
        'IFamilyGroupsService',
        'GetInviteCheckResults',
        request: req,
        accessToken: token,
      ))
          .parse();
      return InviteChecks(
        walletCountryMatches: fields[1]?.asBool ?? false,
        ipMatch: fields[2]?.asBool ?? false,
        joinRestriction: fields[3]?.asInt ?? 0,
      );
    } on SteamApiException catch (e) {
      dlog('inviteChecks unavailable (eresult ${e.eresult}) — degrading');
      return null;
    }
  }

  /// Joins via a pending invite. The invite payload carries no separate
  /// nonce field, so [FamilyInvite.inviteId] is sent as the nonce — the best
  /// available candidate; flagged for real-device verification.
  Future<JoinResult> join(SteamGuardAccount account, FamilyInvite invite) async {
    final token = _requireToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, invite.familyGroupId)
      ..writeUint64(2, invite.inviteId); // nonce
    final fields = (await api.callProtobuf(
      'IFamilyGroupsService',
      'JoinFamilyGroup',
      request: req,
      accessToken: token,
    ))
        .parse();
    // Response has NO field 1 — fields start at 2 (two_factor_method).
    final r = JoinResult(
      twoFactorMethod: fields[2]?.asInt ?? 0,
      cooldownSkipGranted: fields[3]?.asBool ?? false,
      inviteAlreadyAccepted: fields[4]?.asBool ?? false,
      cooldownSecondsRemaining: fields[5]?.asInt ?? 0,
    );
    dlog('family join ${invite.familyGroupId}: 2fa=${r.twoFactorMethod} '
        'already=${r.inviteAlreadyAccepted}');
    return r;
  }

  /// Post-2FA confirmation. Implemented for completeness; whether Steam
  /// requires it after the type-11 mobileconf accept is a real-device
  /// question — the v1 UI flow does not call it.
  Future<void> confirmJoin(
    SteamGuardAccount account, {
    required int familyGroupId,
    required int inviteId,
  }) async {
    final token = _requireToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, familyGroupId)
      ..writeUint64(2, inviteId)
      ..writeUint64(3, inviteId); // nonce = invite_id（同 join）
    await api.callProtobuf(
      'IFamilyGroupsService',
      'ConfirmJoinFamilyGroup',
      request: req,
      accessToken: token,
    );
    // Empty response body; success is the eresult header (callProtobuf throws
    // on any eresult != 1).
  }

  FamilyInvite _invite(List<int> bytes) {
    final f = ProtoReader(Uint8ListView(bytes)).parse();
    return FamilyInvite(
      familyGroupId: f[1]?.asInt ?? 0,
      role: f[2]?.asInt ?? 0,
      inviterSteamId: f[3]?.asFixed64 ?? 0, // fixed64
      awaiting2fa: f[4]?.asBool ?? false,
      inviteId: f[5]?.asInt ?? 0,
    );
  }

  FamilyGroupInfo _group(List<int> bytes) =>
      _groupFromReader(ProtoReader(Uint8ListView(bytes)));

  FamilyGroupInfo _groupFromReader(ProtoReader reader) {
    var name = '';
    final members = <FamilyMember>[];
    var freeSpots = 0;
    var country = '';
    var cooldown = 0;
    for (final f in reader.parseAll()) {
      switch (f.number) {
        case 1:
          name = f.asString;
        case 2: // repeated FamilyGroupMember
          if (f.bytes != null) {
            final m = ProtoReader(Uint8ListView(f.bytes!)).parse();
            members.add(FamilyMember(
              steamId: m[1]?.asFixed64 ?? 0, // fixed64
              role: m[2]?.asInt ?? 0,
              timeJoined: m[3]?.asInt ?? 0,
            ));
          }
        case 4:
          freeSpots = f.asInt;
        case 5:
          country = f.asString;
        case 6:
          cooldown = f.asInt;
      }
    }
    return FamilyGroupInfo(
      name: name,
      members: members,
      freeSpots: freeSpots,
      country: country,
      slotCooldownRemainingSeconds: cooldown,
    );
  }
}

// 小工具：ProtoField.bytes 是 Uint8List，直接可用；此别名仅为可读性。
// ignore: non_constant_identifier_names
Uint8List Uint8ListView(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
```

**实现注意**（执行者按现场调整，属预期内偏差）：
- `ProtoField.bytes` 本身就是 `Uint8List`（见 protobuf_wire.dart）——如果直接 `ProtoReader(f.bytes!)` 能编译，就删掉 `Uint8ListView` 工具函数用直传，保持文件干净；上面的工具函数只是防御 List<int> 情形。
- `import 'dart:typed_data'` 按需添加。
- Dart switch-case 简写（`case 1: x = y;`）需要 Dart 3 pattern 风格；若 analyze 报错改回传统 `case 1: ...; break;`。

- [ ] **Step 4: 跑测试确认通过** — 目标文件全过，然后 `flutter analyze && flutter test` 全绿。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/core/protocol/family_groups_client.dart app/test/core/family_groups_client_test.dart
git commit -m "feat(family): FamilyGroupsClient — protobuf codec for IFamilyGroupsService

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 3: Provider 接线

**Files:**
- Modify: `app/lib/src/app/providers.dart`（`tradeOffersClientProvider` 附近）

- [ ] **Step 1: 实现**

```dart
/// Steam family groups (invites, join, read-only group info) client.
final familyGroupsClientProvider = Provider<FamilyGroupsClient>(
    (ref) => FamilyGroupsClient(ref.read(apiClientProvider)));
```

（import 按字母序插入 core/protocol 组。）

- [ ] **Step 2: 验证 + Commit** — analyze/test 全绿。

```bash
git add app/lib/src/app/providers.dart
git commit -m "chore(app): wire FamilyGroupsClient provider

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 4: l10n 字符串

**Files:**
- Modify: `app/lib/l10n/app_en.arb`、`app_zh.arb`（+ `flutter gen-l10n` 生成文件）

- [ ] **Step 1: 加 key**（`offer*` 组之后；zh 同位置。**注意仓库惯例：`@key` 占位符元数据在 zh 文件里也要镜像一份**——现有 15 个带占位符的 key 中 14 个在 `app_zh.arb` 里带 `@` 条目，照此办理：下方 en 块里所有 `@fam*` 元数据条目原样复制进 zh 块对应位置）

`app_en.arb`：
```json
  "pendingTabInvites": "Invites",
  "famInviteTitle": "「{groupName}」 invited you to join",
  "@famInviteTitle": {"placeholders": {"groupName": {"type": "String"}}},
  "famInviteTitleGeneric": "Family group invite",
  "famInviteFrom": "Invited by {inviter}",
  "@famInviteFrom": {"placeholders": {"inviter": {"type": "String"}}},
  "famInviteRole": "Role: {role}",
  "@famInviteRole": {"placeholders": {"role": {"type": "String"}}},
  "famInviteSlots": "Slots {used}/{total}",
  "@famInviteSlots": {"placeholders": {"used": {"type": "int"}, "total": {"type": "int"}}},
  "famRoleAdult": "Adult",
  "famRoleChild": "Child",
  "famRoleUnknown": "Role #{n}",
  "@famRoleUnknown": {"placeholders": {"n": {"type": "int"}}},
  "famPreflightTitle": "Join checks",
  "famCheckWalletMatch": "Wallet region matches",
  "famCheckWalletMismatch": "Wallet region doesn't match — Steam restricts joining",
  "famCheckIpMatch": "Usual IP matches",
  "famCheckIpMismatch": "IP doesn't match your usual location",
  "famCheckCooldown": "Joining locks family-group switching for 1 year (Steam cooldown)",
  "famJoinRestricted": "Steam blocked this join (restriction {code})",
  "@famJoinRestricted": {"placeholders": {"code": {"type": "int"}}},
  "famInviteJoinHold": "Hold to join",
  "famInviteAwaiting2fa": "Waiting for confirmation — check the Confirmations tab",
  "famInviteJoined": "Joined ✓",
  "famInviteViewGroup": "View family group ›",
  "famJoinSent": "Join requested — confirm it in the Confirmations tab",
  "famJoinDone": "Joined the family group.",
  "famJoinFailed": "Join failed: {msg}",
  "@famJoinFailed": {"placeholders": {"msg": {"type": "String"}}},
  "famInvitesEmpty": "No pending family invites.",
  "famAccountAction": "Family group",
  "famNotInGroup": "This account isn't in a family group.",
  "famSummaryMembers": "Members {used}/{total}",
  "@famSummaryMembers": {"placeholders": {"used": {"type": "int"}, "total": {"type": "int"}}},
  "famSummaryCooldown": "Cooldown {days}d",
  "@famSummaryCooldown": {"placeholders": {"days": {"type": "int"}}},
  "famSectionMembers": "Members",
  "famMemberYou": "(you)",
  "famSectionPending": "Pending",
  "famPendingComingSoon": "Purchase approval is coming in a future update.",
```

`app_zh.arb`：
```json
  "pendingTabInvites": "邀请",
  "famInviteTitle": "「{groupName}」邀请你加入家庭组",
  "famInviteTitleGeneric": "家庭组邀请",
  "famInviteFrom": "邀请人：{inviter}",
  "famInviteRole": "角色：{role}",
  "famInviteSlots": "空位 {used}/{total}",
  "famRoleAdult": "成人",
  "famRoleChild": "儿童",
  "famRoleUnknown": "角色 #{n}",
  "famPreflightTitle": "加入前预检",
  "famCheckWalletMatch": "钱包地区一致",
  "famCheckWalletMismatch": "钱包地区不一致 —— Steam 限制加入",
  "famCheckIpMatch": "常用 IP 匹配",
  "famCheckIpMismatch": "IP 与常用地点不符",
  "famCheckCooldown": "加入后 1 年内不能更换家庭组（官方冷却）",
  "famJoinRestricted": "Steam 阻止了此次加入（限制码 {code}）",
  "famInviteJoinHold": "加入（长按）",
  "famInviteAwaiting2fa": "等待确认 —— 请到「确认」页签处理",
  "famInviteJoined": "已加入 ✓",
  "famInviteViewGroup": "查看家庭组 ›",
  "famJoinSent": "已发起加入 —— 请到「确认」页签完成确认",
  "famJoinDone": "已加入家庭组。",
  "famJoinFailed": "加入失败：{msg}",
  "famInvitesEmpty": "没有待处理的家庭组邀请。",
  "famAccountAction": "家庭组",
  "famNotInGroup": "该账户不在任何家庭组中。",
  "famSummaryMembers": "成员 {used}/{total}",
  "famSummaryCooldown": "冷却 {days} 天",
  "famSectionMembers": "成员",
  "famMemberYou": "（你）",
  "famSectionPending": "待处理",
  "famPendingComingSoon": "购买审批将在后续版本推出。",
```

- [ ] **Step 2: `flutter gen-l10n` + 验证 + Commit**

```bash
git add app/lib/l10n
git commit -m "feat(family): l10n strings for invites tab and family screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 5: FamilyInvitesTab（邀请页签）

**Files:**
- Create: `app/lib/src/ui/pending/family_invites_tab.dart`
（测试与 fake 扩展全部属于 Task 6——本 task 只需编译通过、无回归。）

**骨架完整镜像 `trade_offers_tab.dart`**（keep-alive、公开 State + `refresh()` 防重入、`_fetchWithAutoRefresh`、`_isAuthError`/`_needsLogin`/`_signIn`、`_scrollableCentered`、onCount）。差异点如下，其余照抄该文件模式：

- [ ] **Step 1: 实现**

```dart
// app/lib/src/ui/pending/family_invites_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/family_group.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_offer.dart' show TradeOffer;
import '../../core/protocol/qr_approval_client.dart'
    show MissingAccessTokenException;
import '../../services/session_manager.dart';
import '../../services/steam_api_client.dart' show SteamApiException;
import '../family_group_screen.dart';
import '../login_screen.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';

/// 待办中心第三页签：家庭组邀请。发现邀请（GetFamilyGroupForUser）、
/// 加入前预检（可降级）、长按加入 → type-11 mobileconf 确认联动。
class FamilyInvitesTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final ValueChanged<int>? onCount;
  final VoidCallback? onGoToConfirmations;
  const FamilyInvitesTab({
    super.key,
    required this.account,
    this.onCount,
    this.onGoToConfirmations,
  });

  @override
  ConsumerState<FamilyInvitesTab> createState() => FamilyInvitesTabState();
}

class FamilyInvitesTabState extends ConsumerState<FamilyInvitesTab>
    with AutomaticKeepAliveClientMixin {
  FamilyUserState? _state;
  final _checks = <int, InviteChecks?>{}; // familyGroupId -> checks (null=降级)
  final _checksLoaded = <int>{};
  final _groupNames = <int, FamilyGroupInfo>{}; // 邀请组的名称/空位（可失败）
  final _personas = <int, String>{}; // inviter accountid -> persona
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _needsLogin = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return; // AppBar 按钮 + 下拉可并发触发，防重入
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final s = await _fetchWithAutoRefresh();
      if (!mounted) return;
      setState(() {
        _state = s;
        _loading = false;
      });
      widget.onCount?.call(
          s.pendingInvites.where((i) => !i.awaiting2fa).length);
      _loadDetails(s);
    } catch (e) {
      if (!mounted) return;
      final needsLogin = _isAuthError(e);
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _needsLogin = needsLogin;
        _error = needsLogin ? l.confNeedsLogin : '$e';
      });
    }
  }

  Future<FamilyUserState> _fetchWithAutoRefresh() async {
    final client = ref.read(familyGroupsClientProvider);
    try {
      return await client.forUser(widget.account);
    } catch (_) {
      final refreshed = await SessionManager(ref.read(apiClientProvider))
          .refresh(widget.account.session);
      if (!refreshed) rethrow;
      if (mounted) {
        await ref.read(appControllerProvider).value?.store.save();
      }
      return await client.forUser(widget.account);
    }
  }

  static bool _isAuthError(Object e) =>
      e is MissingAccessTokenException ||
      (e is SteamApiException &&
          (e.message.contains('HTTP 401') || e.message.contains('HTTP 403')));

  Future<void> _signIn() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          LoginScreen(reason: LoginReason.refresh, account: widget.account),
    ));
    if (mounted) refresh();
  }

  /// 每条邀请的补充信息：预检（可降级）、组名/空位（可失败）、邀请人昵称。
  /// 全部 best-effort，逐个 setState；任何失败都不影响卡片主体。
  Future<void> _loadDetails(FamilyUserState s) async {
    final client = ref.read(familyGroupsClientProvider);
    final trade = ref.read(tradeOffersClientProvider);
    for (final invite in s.pendingInvites) {
      if (!_checksLoaded.contains(invite.familyGroupId)) {
        final c = await client.inviteChecks(widget.account, invite.familyGroupId)
            .catchError((_) => null);
        if (!mounted) return;
        setState(() {
          _checksLoaded.add(invite.familyGroupId);
          _checks[invite.familyGroupId] = c;
        });
      }
      if (!_groupNames.containsKey(invite.familyGroupId)) {
        try {
          final g = await client.groupInfo(widget.account, invite.familyGroupId);
          if (!mounted) return;
          setState(() => _groupNames[invite.familyGroupId] = g);
        } catch (_) {
          // 非成员可能无权查看组详情——卡片退回通用标题。
        }
      }
      final accountId = invite.inviterSteamId - TradeOffer.steamId64Base;
      if (accountId > 0 && !_personas.containsKey(accountId)) {
        final (name, _) = await trade.miniProfile(accountId);
        if (!mounted) return;
        if (name.isNotEmpty) {
          setState(() => _personas[accountId] = name);
        }
      }
    }
  }

  Future<void> _join(FamilyInvite invite) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(familyGroupsClientProvider)
          .join(widget.account, invite);
      if (!mounted) return;
      if (r.inviteAlreadyAccepted || !r.needsTwoFactor) {
        messenger.showSnackBar(SnackBar(content: Text(l.famJoinDone)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.famJoinSent)));
        widget.onGoToConfirmations?.call();
      }
      await refresh();
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text(l.famJoinFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabel(AppLocalizations l, int role) => switch (role) {
        1 => l.famRoleAdult, // 社区共识值，真机核对
        2 => l.famRoleChild,
        _ => l.famRoleUnknown(role),
      };

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin contract.
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return RefreshIndicator(onRefresh: refresh, child: _body(l, t));
  }

  Widget _scrollableCentered(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        ),
      );

  Widget _body(AppLocalizations l, AvaTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _scrollableCentered(
        Padding(
          padding: context.rInsets(all: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: t.muted, size: context.r(40)),
              SizedBox(height: context.r(12)),
              Text(_needsLogin ? _error! : '${l.commonError}: $_error',
                  textAlign: TextAlign.center),
              SizedBox(height: context.r(16)),
              _needsLogin
                  ? FilledButton(onPressed: _signIn, child: Text(l.loginButton))
                  : OutlinedButton(
                      onPressed: refresh, child: Text(l.commonRetry)),
            ],
          ),
        ),
      );
    }
    final s = _state;
    final invites = s?.pendingInvites ?? const <FamilyInvite>[];
    if (s != null && s.isMember && invites.isEmpty) {
      // 已在家庭组：空态直接给"查看家庭组"入口。
      return _scrollableCentered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, color: t.good, size: context.r(44)),
            SizedBox(height: context.r(12)),
            Text(l.famInviteJoined),
            SizedBox(height: context.r(12)),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FamilyGroupScreen(
                      account: widget.account,
                      familyGroupId: s.familyGroupId))),
              child: Text(l.famInviteViewGroup),
            ),
          ],
        ),
      );
    }
    if (invites.isEmpty) {
      return _scrollableCentered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, color: t.muted, size: context.r(44)),
            SizedBox(height: context.r(12)),
            Text(l.famInvitesEmpty),
          ],
        ),
      );
    }
    final holdEnabled = ref.watch(holdConfirmProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: context.rInsets(left: 16, top: 12, right: 16, bottom: 16),
      itemCount: invites.length,
      itemBuilder: (context, i) => _inviteCard(
          l, t, invites[i], holdEnabled, hapticsEnabled),
    );
  }

  Widget _inviteCard(AppLocalizations l, AvaTokens t, FamilyInvite invite,
      bool holdEnabled, bool hapticsEnabled) {
    final group = _groupNames[invite.familyGroupId];
    final checks =
        _checksLoaded.contains(invite.familyGroupId)
            ? _checks[invite.familyGroupId]
            : null;
    final restricted = (checks?.joinRestriction ?? 0) != 0;
    final accountId = invite.inviterSteamId - TradeOffer.steamId64Base;
    final inviter = _personas[accountId] ?? '${invite.inviterSteamId}';

    Widget checkLine(bool ok, String okText, String badText, Color badColor) =>
        Padding(
          padding: context.rInsets(top: 2),
          child: Text(ok ? '✓ $okText' : '⚠ $badText',
              style: TextStyle(
                  color: ok ? t.good : badColor, fontSize: context.r(12))),
        );

    return Padding(
      padding: context.rInsets(bottom: 10),
      child: AvaPanel(
        padding: context.rInsets(all: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group != null
                  ? l.famInviteTitle(group.name)
                  : l.famInviteTitleGeneric,
              style: TextStyle(color: t.text, fontSize: context.r(14)),
            ),
            SizedBox(height: context.r(4)),
            Text(
              [
                l.famInviteFrom(inviter),
                l.famInviteRole(_roleLabel(l, invite.role)),
                if (group != null)
                  l.famInviteSlots(group.members.length, group.totalSlots),
              ].join(' · '),
              style: TextStyle(color: t.muted, fontSize: context.r(12)),
            ),
            SizedBox(height: context.r(8)),
            Text(l.famPreflightTitle.toUpperCase(),
                style: TextStyle(
                    color: t.muted,
                    fontSize: context.r(10),
                    letterSpacing: 0.5)),
            if (checks != null) ...[
              checkLine(checks.walletCountryMatches, l.famCheckWalletMatch,
                  l.famCheckWalletMismatch, t.bad),
              checkLine(
                  checks.ipMatch, l.famCheckIpMatch, l.famCheckIpMismatch,
                  t.accent2),
              if (restricted)
                Padding(
                  padding: context.rInsets(top: 2),
                  child: Text(
                      '✗ ${l.famJoinRestricted(checks!.joinRestriction)}',
                      style: TextStyle(
                          color: t.bad, fontSize: context.r(12))),
                ),
            ],
            // 冷却警告始终显示（静态事实，不依赖预检端点）。
            Padding(
              padding: context.rInsets(top: 2),
              child: Text('⚠ ${l.famCheckCooldown}',
                  style:
                      TextStyle(color: t.accent2, fontSize: context.r(12))),
            ),
            SizedBox(height: context.r(10)),
            if (invite.awaiting2fa)
              Text(l.famInviteAwaiting2fa,
                  style: TextStyle(color: t.accent2, fontSize: context.r(12)))
            else
              Row(
                children: [
                  const Spacer(),
                  HoldToConfirmButton(
                    label: l.famInviteJoinHold,
                    color: t.good,
                    // spec 承诺：钱包地区不符 → 禁用加入钮。预检不可用
                    // （checks == null，ePrivilege=5 降级）时不因此禁用。
                    enabled: !_busy &&
                        !restricted &&
                        (checks?.walletCountryMatches ?? true),
                    holdEnabled: holdEnabled,
                    hapticsEnabled: hapticsEnabled,
                    onConfirmed: () => _join(invite),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

**实现注意**：`checks!.joinRestriction` 处 analyze 可能提示不必要的 `!`（前面已判空）——以 analyze 为准调整。`catchError((_) => null)` 的类型如报错，用 try/catch 包裹替代。

- [ ] **Step 2: 本 task 只保证编译**（页签还未接入 UI，测试在 Task 6 一起写）：`flutter analyze` 零问题、`flutter test` 全绿（无回归）。

- [ ] **Step 3: Commit**

```bash
git add app/lib/src/ui/pending/family_invites_tab.dart app/lib/src/ui/family_group_screen.dart
git commit -m "feat(family): invites tab — discovery, preflight, hold-to-join

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

（本 task 引用了 Task 7 的 `FamilyGroupScreen` —— 按顺序执行到这里它还不存在：先创建最小占位版本（构造签名与 Task 7 完全一致：`FamilyGroupScreen({super.key, required this.account, this.familyGroupId})` + 空 Scaffold）保证编译，**占位文件随本 commit 一起提交**（上面的 git add 已包含），Task 7 再实装；照计划 1 Task 9/10 的占位先例，commit message 里注明。）

---

### Task 6: PendingScreen 第三页签接线 + 测试

**Files:**
- Modify: `app/lib/src/ui/pending/pending_screen.dart`
- Modify: `app/test/ui/pending_screen_test.dart`

- [ ] **Step 1: 接线**（对照现文件 L21-100）

- `TabController(length: 2 → 3)`；
- 加 `final _familyTabKey = GlobalKey<FamilyInvitesTabState>();` 与 `int? _familyCount;`；
- AppBar 刷新按钮加 `if (_tabs.index == 2) _familyTabKey.currentState?.refresh();`；
- TabBar 加 `_tab(l.pendingTabInvites, _familyCount)`；
- TabBarView 加：

```dart
            FamilyInvitesTab(
              key: _familyTabKey,
              account: widget.account,
              onCount: (n) => setState(() => _familyCount = n),
              onGoToConfirmations: () {
                _tabs.animateTo(0);
                // keep-alive 的确认页签不会自己重拉——不刷新的话用户会落在
                // 旧数据上（同报价页签的既有教训）。
                _confTabKey.currentState?.refresh();
              },
            ),
```

- 文件头"计划 2 加入"的注释同步删除/更新。

- [ ] **Step 2: 测试**

1. **基础 `_FakeApi` 补 `callProtobuf` override**（关键：否则邀请页签的 initState 拉取会打真网络，所有既有用例都受影响）：

```dart
  int familyCalls = 0;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    if (method == 'GetFamilyGroupForUser') familyCalls++;
    return ProtoReader(Uint8List(0)); // 空响应 = 无邀请、非成员
  }
```

（顶部补 `import 'dart:typed_data';` 与 protobuf_wire/steam_api_client 的相应 import。）

2. 既有 "renders both tabs and switches" 用例改为断言三个页签（`Invites` 也在）；keep-alive 用例补一条——**注意 TabBarView 懒构建**：先切到 Invites 一次（触发 initState 首拉），**然后**取 `getlistCalls`/`familyCalls` 基线，再切走、切回，断言两个计数都不增加。基线取早了会把首拉误判为 keep-alive 失效。

3. 新 fake `_FakeApiWithInvite extends _FakeApi`：`GetFamilyGroupForUser` 返回一条邀请（用 ProtoWriter 构造，photocopy Task 2 测试的 `_forUserResp` 单邀请版），`GetInviteCheckResults` 抛 `SteamApiException(15, 'denied', 'GetInviteCheckResults')`（走降级路径），`GetFamilyGroup` 抛 `SteamApiException(2, 'fail', 'GetFamilyGroup')`（通用标题路径）。新用例断言：切到 Invites 页签后出现 `famInviteTitleGeneric` 文案（'Family group invite'）、`Hold to join` 按钮、静态冷却警告行存在、且**没有**钱包/IP 预检行（降级生效）。

3b. **钱包不符禁用用例**（spec 承诺，对抗审查补入）：fake 变体让 `GetInviteCheckResults` 返回 `wallet_country_matches=false`（ProtoWriter：`writeBool(1, false)..writeBool(2, true)..writeVarint(3, 0)`）→ 断言 `famCheckWalletMismatch` 文案出现，且 `Hold to join` 按钮 disabled（`tester.widget<HoldToConfirmButton>(...).enabled == false`）。

4. join 流程用例：`_FakeApiWithInvite` 的 `JoinFamilyGroup` 返回 `two_factor_method=1`；驱动长按（150ms 预 pump + 1000ms，照抄现有 hold 驱动模式）→ 断言 famJoinSent SnackBar、TabController 回到 index 0、`getlistCalls` 增加（确认页签被强制刷新）。

- [ ] **Step 3: 全量验证 + Commit**

```bash
git add app/lib/src/ui/pending/pending_screen.dart app/test/ui/pending_screen_test.dart
git commit -m "feat(family): third pending tab — invites wired with badge and handoff

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 7: FamilyGroupScreen（只读信息页）+ 账户菜单入口

**Files:**
- Create: `app/lib/src/ui/family_group_screen.dart`
- Modify: `app/lib/src/ui/home_screen.dart`（菜单 + `_onAction`）
- Test: `app/test/ui/family_group_screen_test.dart`

- [ ] **Step 1: 实现信息页**

```dart
// app/lib/src/ui/family_group_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/family_group.dart';
import '../core/models/steam_guard_account.dart';
import '../core/models/trade_offer.dart' show TradeOffer;
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

/// 只读的家庭组信息页：摘要（成员/冷却）+ 成员列表 + 购买审批占位。
/// [familyGroupId] 为 null 时先查 GetFamilyGroupForUser（账户菜单入口）。
class FamilyGroupScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final int? familyGroupId;
  const FamilyGroupScreen(
      {super.key, required this.account, this.familyGroupId});

  @override
  ConsumerState<FamilyGroupScreen> createState() => _FamilyGroupScreenState();
}

class _FamilyGroupScreenState extends ConsumerState<FamilyGroupScreen> {
  FamilyGroupInfo? _group;
  bool _notInGroup = false;
  bool _loading = true;
  String? _error;
  final _personas = <int, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notInGroup = false;
    });
    try {
      final client = ref.read(familyGroupsClientProvider);
      var groupId = widget.familyGroupId;
      FamilyGroupInfo? group;
      if (groupId == null) {
        final s = await client.forUser(widget.account);
        if (!s.isMember) {
          if (!mounted) return;
          setState(() {
            _notInGroup = true;
            _loading = false;
          });
          return;
        }
        groupId = s.familyGroupId;
        group = s.group; // include_family_group_response 可能已带回
      }
      group ??= await client.groupInfo(widget.account, groupId);
      if (!mounted) return;
      setState(() {
        _group = group;
        _loading = false;
      });
      _loadPersonas(group); // 此处 group 已被流程提升为非空，勿加 `!`
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadPersonas(FamilyGroupInfo group) async {
    final trade = ref.read(tradeOffersClientProvider);
    for (final m in group.members) {
      final accountId = m.steamId - TradeOffer.steamId64Base;
      if (accountId <= 0 || _personas.containsKey(accountId)) continue;
      final (name, _) = await trade.miniProfile(accountId);
      if (!mounted) return;
      if (name.isNotEmpty) setState(() => _personas[accountId] = name);
    }
  }

  String _roleLabel(AppLocalizations l, int role) => switch (role) {
        1 => l.famRoleAdult,
        2 => l.famRoleChild,
        _ => l.famRoleUnknown(role),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? l.famAccountAction),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ScanlineOverlay(child: _body(l, t)),
    );
  }

  Widget _body(AppLocalizations l, AvaTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notInGroup) {
      return Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Text(l.famNotInGroup, textAlign: TextAlign.center),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: t.muted, size: context.r(40)),
              SizedBox(height: context.r(12)),
              Text('${l.commonError}: $_error', textAlign: TextAlign.center),
              SizedBox(height: context.r(16)),
              OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
            ],
          ),
        ),
      );
    }
    final g = _group!;
    final cooldownDays =
        (g.slotCooldownRemainingSeconds / 86400).ceil();
    return ListView(
      padding: context.rInsets(all: 16),
      children: [
        AvaPanel(
          padding: context.rInsets(all: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.famSummaryMembers(g.members.length, g.totalSlots),
                  style: TextStyle(color: t.text, fontSize: context.r(13))),
              if (g.slotCooldownRemainingSeconds > 0)
                Text(l.famSummaryCooldown(cooldownDays),
                    style: TextStyle(
                        color: t.accent2, fontSize: context.r(13))),
            ],
          ),
        ),
        SizedBox(height: context.r(16)),
        Text(l.famSectionMembers.toUpperCase(),
            style: TextStyle(
                color: t.muted, fontSize: context.r(11), letterSpacing: 0.5)),
        SizedBox(height: context.r(6)),
        for (final m in g.members)
          Padding(
            padding: context.rInsets(bottom: 6),
            child: AvaPanel(
              padding: context.rInsets(all: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _memberName(m) +
                          (m.steamId == widget.account.steamId
                              ? ' ${l.famMemberYou}'
                              : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: t.text, fontSize: context.r(13)),
                    ),
                  ),
                  Text(_roleLabel(l, m.role),
                      style: TextStyle(
                          color: t.muted, fontSize: context.r(12))),
                ],
              ),
            ),
          ),
        SizedBox(height: context.r(16)),
        Text(l.famSectionPending.toUpperCase(),
            style: TextStyle(
                color: t.muted, fontSize: context.r(11), letterSpacing: 0.5)),
        SizedBox(height: context.r(6)),
        AvaPanel(
          padding: context.rInsets(all: 12),
          child: Text(l.famPendingComingSoon,
              style: TextStyle(color: t.muted, fontSize: context.r(12))),
        ),
        // 注意：本版无"退出家庭组"——只读页不呈现未实现的能力（spec 二期）。
      ],
    );
  }

  String _memberName(FamilyMember m) {
    final accountId = m.steamId - TradeOffer.steamId64Base;
    return _personas[accountId] ?? '${m.steamId}';
  }
}
```

- [ ] **Step 2: 账户菜单入口**（home_screen.dart）

- home_screen.dart 顶部相对 import 组（`login_screen.dart`/`market_screen.dart` 附近）加 `import 'family_group_screen.dart';`
- `_contextMenu` 的 items 里 `item('market', ...)` 之后加：`item('family', Icons.family_restroom, l.famAccountAction),`
- `_onAction` 加分支：

```dart
      case 'family':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FamilyGroupScreen(account: account)));
        break;
```

（滑动面板不加——`extentRatio` 空间有限，桌面右键菜单 + 邀请页签入口已覆盖两端。）

- [ ] **Step 3: 冒烟测试**（`app/test/ui/family_group_screen_test.dart`，照抄 pending_screen_test 的 `_app` 包装模式改 home 为 FamilyGroupScreen）：fake `callProtobuf` 对 `GetFamilyGroup` 返回 Task 2 的 `_groupResp` 等价物（直接 groupId 入参路径）；断言组名 'Wang 家'、两行成员、`famPendingComingSoon` 文案、无"退出"字样。再一条：`GetFamilyGroupForUser` 返回空（非成员）+ groupId 为 null 入参 → 断言 `famNotInGroup` 文案。

- [ ] **Step 4: 全量验证 + Commit**

```bash
git add -A app/lib app/test
git commit -m "feat(family): read-only family group screen + account menu entry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 8: 收尾

- [ ] **Step 1: 全量 CI** — `cd app && flutter analyze && flutter test` 零问题全绿。

- [ ] **Step 2: 执行后记**（追加到本计划文件）：spec 收窄三条（谢绝、共享游戏数、菜单入口始终显示）+ 新遗留项。

- [ ] **Step 3: 真机联调清单**（追加到本计划文件；模拟器 mock 账户优先，真机只读验证，勿动确认页——CLAUDE.md 红线）

- [ ] `GetFamilyGroupForUser` 真实响应解析（邀请、成员身份、嵌套 group）
- [ ] `GetInviteCheckResults` 用户 token 可用性（ePrivilege=5 降级路径是否触发）
- [ ] `JoinFamilyGroup` 的 nonce=invite_id 是否被接受；失败时的 eresult
- [ ] join 后 type-11 确认出现在确认页签并可接受；接受后 `ConfirmJoinFamilyGroup` 是否必调
- [ ] type-11 确认卡 chip 显示为「家庭组邀请」（计划 1 交接项）
- [ ] role 值语义核对（1=成人 2=儿童？组长的值？）
- [ ] 信息页成员/空位/冷却与官方客户端对照

- [ ] **Step 4: 版本与 CHANGELOG** — 按用户 **b** 指令触发，不在本计划内自动执行。

---

## 执行后记（2026-07-15，全分支终审后）

**结果**：Task 1-7 由实施工作流完成（每任务双审并行，全部首轮通过，零修复轮）；
12 条 Minor 中 9 条已在清理提交（`8a99a0a`/`e1e16f8`）修复；终审两项合并前修正
（zh `famInviteSlots` 语义、本后记）已落。251/251 测试全绿，analyze 零问题。

**Spec 收窄（最终确认）**：谢绝邀请（收件人侧 RPC 未确认）、共享游戏数
（`GetSharedLibraryApps` 超范围）、账户菜单入口始终显示、"已加入"卡片转换需
手动刷新、只读页无退出按钮、购买审批仅占位。

**遗留清单（非阻塞）**：
1. 邀请详情缓存（预检/组名/昵称）跨刷新不失效——瞬时网络错误会让卡片降级
   直到重开待办中心；可在 `refresh()` 里清三个 guard 集合
2. "长按加入"的 AT 语义激活直达 `_join`（单条操作先例一致，但 join 带一年
   冷却且 `two_factor_method=0` 时立即生效——考虑批量 pill 的弹窗处理）
3. 已加入空态与 awaiting_2fa 卡片文案无 widget 测试
4. 昵称查询无负缓存（空结果每次刷新重拉）
5. `home_screen` `case 'family'` 未 await push（同级 case 有，纯风格）

**真机首轮反馈（2026-07-15，折叠屏 192.168.1.83）**：邀请页签报 HTTP 405——
`GetFamilyGroupForUser`/`GetFamilyGroup`/`GetInviteCheckResults` 均为
`bConstMethod=true`，必须 GET（proto 侦察已引用该标注但未连接到 `useGet`，
三层审查亦未捕获——已修复并以测试钉住 GET/POST 语义）。确认页签真机可正常查看。
错误展示同时改为只显示 `SteamApiException.message`。

**本功能在真机验证前应视为实验性**——协议层最大的赌注是 nonce=invite_id 与
ePrivilege=5 降级，见下方清单。

## Self-Review 记录

- **Spec 覆盖**：邀请发现/预检/长按加入/确认联动（Task 5-6）、信息页（Task 7）、provider（Task 3）、l10n（Task 4）、协议层含 ConfirmJoinFamilyGroup 备用实现（Task 2）。收窄三条显式记录于头部。
- **占位符扫描**：Task 5 对 FamilyGroupScreen 的前向引用有占位指引（照计划 1 先例）；无 TBD。
- **类型一致性**：`FamilyInvite`/`FamilyUserState` 字段 ↔ Task 2 测试 ↔ Task 5 用法；`FamilyInvitesTabState`/`refresh()` ↔ Task 6 GlobalKey；`familyGroupsClientProvider` ↔ Task 5/7 的 `ref.read`；hold button 参数 ↔ 现有签名（侦察核对）。
- **执行顺序**：1→2→3→4→(5↔7 占位规则)→6→8。
