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
