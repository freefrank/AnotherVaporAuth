import 'dart:typed_data';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/family_group.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';
import 'community_session.dart';

/// Steam Family Groups (`IFamilyGroupsService`, webui protobuf surface).
/// Field numbers follow SteamDatabase/Protobufs webui/service_familygroups.proto
/// — verbatim-checked; see the plan's 协议事实 table. All calls authenticate
/// with the account's access token.
class FamilyGroupsClient {
  final SteamApiClient api;
  FamilyGroupsClient(this.api);

  /// This account's family situation: current group + pending invites.
  Future<FamilyUserState> forUser(SteamGuardAccount account) async {
    final token = requireAccessToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, account.steamId) // steamid (uint64 varint, NOT fixed64)
      ..writeBool(2, true); // include_family_group_response
    final reader = await api.callProtobuf(
      'IFamilyGroupsService',
      'GetFamilyGroupForUser',
      request: req,
      accessToken: token,
      // bConstMethod=true — POST 会被 api.steampowered.com 以 HTTP 405 拒绝
      // （真机验证发现），const 方法必须 GET，同 GetAuthSessionsForAccount。
      useGet: true,
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
    final token = requireAccessToken(account);
    final req = ProtoWriter()..writeUint64(1, familyGroupId);
    final reader = await api.callProtobuf(
      'IFamilyGroupsService',
      'GetFamilyGroup',
      request: req,
      accessToken: token,
      useGet: true, // bConstMethod=true（同上，POST → 405）
    );
    return _groupFromReader(reader);
  }

  /// Pre-join checks. Valve marks this endpoint ePrivilege=5 (internal), so a
  /// plain user token may be refused — any [SteamApiException] degrades to
  /// null and the UI simply hides the dynamic check rows.
  Future<InviteChecks?> inviteChecks(
      SteamGuardAccount account, int familyGroupId) async {
    final token = requireAccessToken(account);
    final req = ProtoWriter()
      ..writeUint64(1, familyGroupId)
      ..writeFixed64(2, account.steamId); // steamid (fixed64 here!)
    try {
      final fields = (await api.callProtobuf(
        'IFamilyGroupsService',
        'GetInviteCheckResults',
        request: req,
        accessToken: token,
        useGet: true, // bConstMethod=true（同上，POST → 405）
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
    final token = requireAccessToken(account);
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
    final token = requireAccessToken(account);
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

  FamilyInvite _invite(Uint8List bytes) {
    final f = ProtoReader(bytes).parse();
    return FamilyInvite(
      familyGroupId: f[1]?.asInt ?? 0,
      role: f[2]?.asInt ?? 0,
      inviterSteamId: f[3]?.asFixed64 ?? 0, // fixed64
      awaiting2fa: f[4]?.asBool ?? false,
      inviteId: f[5]?.asInt ?? 0,
    );
  }

  FamilyGroupInfo _group(Uint8List bytes) => _groupFromReader(ProtoReader(bytes));

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
            final m = ProtoReader(f.bytes!).parse();
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
