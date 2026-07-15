// app/lib/src/core/models/family_group.dart

/// A pending family-group invite for this account
/// (FamilyGroupPendingInviteForUser).
class FamilyInvite {
  final int familyGroupId;
  final int role; // opaque Steam role id; the UI maps known values (1/2) to labels
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
