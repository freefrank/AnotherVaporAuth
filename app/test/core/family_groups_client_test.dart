import 'dart:typed_data';

import 'package:ava/src/core/models/family_group.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/family_groups_client.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart'
    show MissingAccessTokenException;
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
  final Object? throwOnCall;
  String? lastMethod;
  ProtoWriter? lastRequest;
  String? lastAccessToken;
  bool? lastUseGet;
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
    lastUseGet = useGet;
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

/// 构造 GetFamilyGroup 响应体（writer 形态，可整体嵌进 forUser 的字段 8）：
/// 组名 + 两个成员 + 空位。
ProtoWriter _groupWriter() {
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

ProtoReader _groupResp() => ProtoReader(_groupWriter().toBytes());

void main() {
  group('forUser', () {
    test('parses repeated nested invites incl. fixed64 inviter', () async {
      final api = _FakeApi([_forUserResp()]);
      final s = await FamilyGroupsClient(api).forUser(_account());
      expect(api.lastMethod, 'IFamilyGroupsService/GetFamilyGroupForUser');
      // bConstMethod=true → 必须 GET（POST 被 405 拒，真机验证）。
      expect(api.lastUseGet, isTrue);
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

    test('parses member state: groupid/role/cooldown + nested group (field 8)',
        () async {
      final w = ProtoWriter()
        ..writeUint64(1, 9001) // family_groupid
        ..writeVarint(6, 1) // role
        ..writeVarint(7, 86400) // cooldown_seconds_remaining
        ..writeMessage(8, _groupWriter()); // include_family_group_response
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final s = await FamilyGroupsClient(api).forUser(_account());
      expect(s.isMember, isTrue);
      expect(s.familyGroupId, 9001);
      expect(s.role, 1);
      expect(s.cooldownSecondsRemaining, 86400);
      expect(s.group?.name, 'Wang 家');
      expect(s.pendingInvites, isEmpty);
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
    expect(api.lastUseGet, isTrue); // bConstMethod=true → GET
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
      expect(api.lastUseGet, isTrue); // bConstMethod=true → GET
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
      expect(api.lastUseGet, isFalse); // 非 const 方法 → POST
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
    expect(api.lastUseGet, isFalse); // 非 const 方法 → POST
    final req = ProtoReader(api.lastRequest!.toBytes()).parse();
    expect(req[1]?.varint, 9001);
    expect(req[2]?.varint, 555001);
    expect(req[3]?.varint, 555001); // nonce = invite_id
  });
}
