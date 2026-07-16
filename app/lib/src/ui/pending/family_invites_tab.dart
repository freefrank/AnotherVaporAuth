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
  final _groupInfoRequested = <int>{}; // in-flight/已请求守卫，防并发重复拉取
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
        _error = needsLogin
            ? l.confNeedsLogin
            // SteamApiException 的完整 toString 对用户像未捕获的崩溃 ——
            // 只显示其 message（如 "HTTP 405"），其余异常保持原样。
            : (e is SteamApiException ? e.message : '$e');
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
        // await 前登记，防并发 _loadDetails 重复拉取（纯簿记，无需 setState）。
        _checksLoaded.add(invite.familyGroupId);
        final c = await client.inviteChecks(widget.account, invite.familyGroupId)
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
                // 邀请人 steamid 缺失（0）时整段省略，不渲染字面 '0'。
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
              checkLine(
                  checks.ipMatch, l.famCheckIpMatch, l.famCheckIpMismatch,
                  t.accent2),
              if (restricted)
                Padding(
                  padding: context.rInsets(top: 2),
                  child: Text(
                      '✗ ${l.famJoinRestricted(checks.joinRestriction)}',
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
