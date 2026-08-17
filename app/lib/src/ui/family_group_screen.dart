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
import 'pending/pending_screen.dart';
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/hold_button.dart';
import 'widgets/scanline_overlay.dart';
import 'error_text.dart';

/// The account's family-group hub: pending invites (discover → preflight →
/// hold-to-join, previously the todo-center "Invites" tab) plus the read-only
/// group snapshot (members / cooldown). Reached from the account long-press
/// menu.
///
/// [familyGroupId] non-null → jump straight to that group's read-only view
/// (no invites). Null → resolve via GetFamilyGroupForUser: show any pending
/// invites, and the group below when the account is already a member.
class FamilyGroupScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final int? familyGroupId;
  const FamilyGroupScreen(
      {super.key, required this.account, this.familyGroupId});

  @override
  ConsumerState<FamilyGroupScreen> createState() => _FamilyGroupScreenState();
}

class _FamilyGroupScreenState extends ConsumerState<FamilyGroupScreen>
    with SessionRetryState {
  FamilyUserState? _userState; // only on the familyGroupId == null path
  FamilyGroupInfo? _group; // the member's / requested group
  bool _loading = true;
  bool _busy = false; // a join is in flight
  String? _error;
  bool _needsLogin = false;

  // Per-invite best-effort enrichment (all optional, fed one setState each).
  final _checks = <int, InviteChecks?>{}; // familyGroupId -> checks (null=降级)
  final _checksLoaded = <int>{};
  final _groupNames = <int, FamilyGroupInfo>{};
  final _groupInfoRequested = <int>{};
  final _personas = <int, String>{}; // accountid -> persona

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final client = ref.read(familyGroupsClientProvider);
      // A specific group id → read-only group view, no invite lookup (keeps the
      // old direct-view behaviour and its tests).
      if (widget.familyGroupId != null) {
        final group = await fetchWithAutoRefresh<FamilyGroupInfo>(widget.account,
            () => client.groupInfo(widget.account, widget.familyGroupId!));
        if (!mounted) return;
        setState(() {
          _group = group;
          _loading = false;
        });
        _loadPersonas(group);
        return;
      }
      // The long-press entry: resolve membership + pending invites in one call.
      final s = await fetchWithAutoRefresh<FamilyUserState>(
          widget.account, () => client.forUser(widget.account));
      if (!mounted) return;
      FamilyGroupInfo? group;
      if (s.isMember) {
        // include_family_group_response may already carry the group (field 8);
        // fall back to a GetFamilyGroup only when it didn't.
        group = s.group ??
            await client.groupInfo(widget.account, s.familyGroupId);
      }
      if (!mounted) return;
      setState(() {
        _userState = s;
        _group = group;
        _loading = false;
      });
      _loadInviteDetails(s);
      if (group != null) _loadPersonas(group);
    } catch (e) {
      if (!mounted) return;
      final needsLogin = isAuthError(e);
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _needsLogin = needsLogin;
        _error = needsLogin ? l.confNeedsLogin : fetchErrorText(l, e);
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

  /// Best-effort per-invite enrichment: preflight (may degrade), group name /
  /// slots (may fail), inviter persona. Invites load in parallel.
  Future<void> _loadInviteDetails(FamilyUserState s) =>
      Future.wait([for (final i in s.pendingInvites) _loadInviteDetails1(i)]);

  Future<void> _loadInviteDetails1(FamilyInvite invite) async {
    final client = ref.read(familyGroupsClientProvider);
    final trade = ref.read(tradeOffersClientProvider);
    if (!_checksLoaded.contains(invite.familyGroupId)) {
      _checksLoaded.add(invite.familyGroupId);
      final c = await client
          .inviteChecks(widget.account, invite.familyGroupId)
          .catchError((_) => null);
      if (!mounted) return;
      setState(() => _checks[invite.familyGroupId] = c);
    }
    if (!_groupNames.containsKey(invite.familyGroupId) &&
        !_groupInfoRequested.contains(invite.familyGroupId)) {
      _groupInfoRequested.add(invite.familyGroupId);
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
      if (name.isNotEmpty) setState(() => _personas[accountId] = name);
    }
  }

  Future<void> _join(FamilyInvite invite) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(familyGroupsClientProvider)
          .join(widget.account, invite);
      if (!mounted) return;
      if (r.inviteAlreadyAccepted || !r.needsTwoFactor) {
        messenger.showSnackBar(SnackBar(content: Text(l.famJoinDone)));
        await _load();
      } else {
        // A mobile confirmation follows — send the user to the todo center to
        // approve it (the standalone screen has no confirmations tab of its
        // own, unlike the old in-tab flow).
        messenger.showSnackBar(SnackBar(content: Text(l.famJoinSent)));
        navigator.push(MaterialPageRoute(
            builder: (_) => PendingScreen(account: widget.account)));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.famJoinFailed(describeError(l, e)))));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (_error != null) {
      return Center(
        child: sessionErrorBody(
          l,
          t,
          error: _error!,
          needsLogin: _needsLogin,
          onSignIn: () => signInThen(widget.account, _load),
          onRetry: _load,
        ),
      );
    }
    final invites = _userState?.pendingInvites ?? const <FamilyInvite>[];
    final group = _group;
    // Nothing to show: not a member and no pending invite.
    if (group == null && invites.isEmpty) {
      return Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Text(l.famNotInGroup, textAlign: TextAlign.center),
        ),
      );
    }
    final holdEnabled = ref.watch(holdConfirmProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);
    return ListView(
      padding: context.rSafeInsets(all: 16),
      children: [
        if (invites.isNotEmpty) ...[
          Text(l.famInvitesSection.toUpperCase(),
              style: TextStyle(
                  color: t.muted, fontSize: context.r(11), letterSpacing: 0.5)),
          SizedBox(height: context.r(6)),
          for (final i in invites)
            _inviteCard(l, t, i, holdEnabled, hapticsEnabled),
          if (group != null) SizedBox(height: context.r(16)),
        ],
        if (group != null) ..._groupSection(l, t, group),
      ],
    );
  }

  List<Widget> _groupSection(AppLocalizations l, AvaTokens t, FamilyGroupInfo g) {
    final cooldownDays = (g.slotCooldownRemainingSeconds / 86400).ceil();
    return [
      AvaPanel(
        padding: context.rInsets(all: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l.famSummaryMembers(g.members.length, g.totalSlots),
                style: TextStyle(color: t.text, fontSize: context.r(13))),
            if (g.slotCooldownRemainingSeconds > 0)
              Text(l.famSummaryCooldown(cooldownDays),
                  style:
                      TextStyle(color: t.accent2, fontSize: context.r(13))),
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
                    style: TextStyle(color: t.text, fontSize: context.r(13)),
                  ),
                ),
                Text(_roleLabel(l, m.role),
                    style: TextStyle(color: t.muted, fontSize: context.r(12))),
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
    ];
  }

  Widget _inviteCard(AppLocalizations l, AvaTokens t, FamilyInvite invite,
      bool holdEnabled, bool hapticsEnabled) {
    final group = _groupNames[invite.familyGroupId];
    final checks = _checksLoaded.contains(invite.familyGroupId)
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
                if (invite.inviterSteamId != 0) l.famInviteFrom(inviter),
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
              checkLine(checks.ipMatch, l.famCheckIpMatch, l.famCheckIpMismatch,
                  t.accent2),
              if (restricted)
                Padding(
                  padding: context.rInsets(top: 2),
                  child: Text('✗ ${l.famJoinRestricted(checks.joinRestriction)}',
                      style:
                          TextStyle(color: t.bad, fontSize: context.r(12))),
                ),
            ],
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

  String _memberName(FamilyMember m) {
    final accountId = m.steamId - TradeOffer.steamId64Base;
    return _personas[accountId] ?? '${m.steamId}';
  }
}
