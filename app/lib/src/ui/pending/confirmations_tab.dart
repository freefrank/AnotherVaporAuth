import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/confirmation.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/protocol/confirmations_client.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';
import 'session_retry.dart';

/// Design screen 06 — confirmations. Native JSON rendering (no WebView). Top
/// batch bar (accept all / reject all) + per-item cards with type chip, title,
/// summary and accept/reject. Items stagger in; acted items slide out.
/// Hosted as a tab inside PendingScreen, which owns the Scaffold/AppBar.
class ConfirmationsTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;

  /// Reports the pending count to the parent after a successful fetch, so the
  /// pending center can badge this tab.
  final ValueChanged<int>? onCount;
  const ConfirmationsTab({super.key, required this.account, this.onCount});

  @override
  ConsumerState<ConfirmationsTab> createState() => ConfirmationsTabState();
}

/// Public so PendingScreen can delegate the AppBar refresh action via a
/// GlobalKey. Kept alive across tab switches: re-creating the state would
/// re-sign and re-fetch from Steam mobileconf on every switch and drop
/// scroll position / in-flight responses.
class ConfirmationsTabState extends ConsumerState<ConfirmationsTab>
    with AutomaticKeepAliveClientMixin, SessionRetryState {
  late final ConfirmationsClient _client;
  List<Confirmation>? _confs;
  // false so the initState refresh passes its own re-entrancy guard;
  // refresh() flips it to true before the first frame builds.
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _needsLogin = false; // session needs interactive sign-in, not a retry

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _client = ConfirmationsClient(ref.read(apiClientProvider));
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return; // AppBar 按钮 + 下拉可并发触发,防重入
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      // A stale session (`needauth` → ConfirmationAuthException) transparently
      // refreshes the token and retries once; only a dead refresh token
      // surfaces as an error. Other failures skip the token exchange.
      final list = await fetchWithAutoRefresh(
          widget.account, () => _client.fetch(widget.account),
          retryOnAnyError: false);
      if (!mounted) return;
      setState(() {
        _confs = list;
        _loading = false;
      });
      widget.onCount?.call(list.length);
    } catch (e) {
      if (!mounted) return;
      final needsLogin = isAuthError(e);
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _needsLogin = needsLogin;
        _error = needsLogin
            ? l.confNeedsLogin
            // A signature-level rejection is a configuration problem, not a
            // transient error — explain the likely causes instead of dumping
            // the exception (Steam's own message is appended when present).
            : e is ConfirmationRejectedException
                ? (e.message.isEmpty
                    ? l.confRejected
                    : '${l.confRejected}\n\nSteam: ${e.message}')
                : '$e';
      });
    }
  }

  Future<void> _respond(List<Confirmation> confs, bool accept) async {
    // 多点触控下卡片 ✓ 与批量 pill 的长按可在同一帧完成 —— 防双发。
    if (_busy) return;
    if (confs.isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.confProcessing(confs.length))),
    );
    final result = await _client.respondMultiple(widget.account, confs, accept);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.confResult(result.ok, result.failed))),
    );
    await refresh();
  }

  /// Batch accept/reject with an explicit confirmation dialog — acting on
  /// every pending confirmation must never be a single tap. Serves the reject
  /// path (always dialog-gated) and accept-all when the hold-to-confirm
  /// toggle is off; with hold enabled, accept-all's long press is itself the
  /// second confirmation and calls [_respond] directly — except for assistive
  /// tech, whose semantic activation is routed back here (see the batch
  /// pill's `onSemanticConfirmed`).
  Future<void> _respondAll(List<Confirmation> confs, bool accept) async {
    if (confs.isEmpty) return;
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept
            ? l.confAcceptAllConfirm(confs.length)
            : l.confRejectAllConfirm(confs.length)),
        content: Text(accept ? l.confAcceptAllWarn : l.confRejectAllWarn),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
            // Destructive emphasis for reject; accept keeps the accent.
            style: accept
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: t.bad,
                    foregroundColor: const Color(0xFF06060F),
                  ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accept ? l.confAcceptAll : l.confRejectAll),
          ),
        ],
      ),
    );
    if (ok == true) await _respond(confs, accept);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin contract.
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final confs = _confs ?? const <Confirmation>[];

    // Pull-to-refresh; desktop mouse users use the AppBar refresh action in
    // PendingScreen, which delegates here via GlobalKey.
    return RefreshIndicator(
      onRefresh: refresh,
      child: _buildBody(l, t, confs),
    );
  }

  Widget _buildBody(
      AppLocalizations l, AvaTokens t, List<Confirmation> confs) {
    if (_loading) {
      // Non-scrollable on purpose: pull-to-refresh is pointless mid-load.
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return scrollableCentered(sessionErrorBody(
        l,
        t,
        error: _error!,
        needsLogin: _needsLogin,
        onSignIn: () => signInThen(widget.account, refresh),
        onRetry: refresh,
      ));
    }
    if (confs.isEmpty) {
      return scrollableCentered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                color: t.good, size: context.r(44)),
            SizedBox(height: context.r(12)),
            Text(l.confirmationsEmpty),
          ],
        ),
      );
    }

    // Watched here (inside build), not in the lazy itemBuilder closure —
    // ref.watch is only legal during build, and the settings toggles must
    // rebuild the cards when flipped.
    final holdEnabled = ref.watch(holdConfirmProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);

    return Column(
      children: [
        // Batch bar
        Padding(
          padding: context.rInsets(left: 16, top: 14, right: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.confPending(confs.length),
                  style: TextStyle(color: t.text, fontSize: context.r(14)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _respondAll(confs, false),
                icon: Icon(Icons.close, size: context.r(16)),
                label: Text(l.confRejectAll),
              ),
              SizedBox(width: context.r(8)),
              // 长按开启时,长按本身就是二次确认 —— 直接执行,不再弹窗;
              // 关闭长按则退回弹窗作为批量操作的安全底线。
              holdEnabled
                  ? HoldToConfirmButton(
                      label: l.confAcceptAll,
                      color: t.good,
                      enabled: !_busy,
                      hapticsEnabled: hapticsEnabled,
                      onConfirmed: () => _respond(confs, true),
                      // 辅助技术做不了计时长按,语义激活是直接触发 —— 批量
                      // 操作必须把这条通道引回弹窗二次确认,不能一次双击全收。
                      onSemanticConfirmed: () => _respondAll(confs, true),
                    )
                  : FilledButton.icon(
                      onPressed: _busy ? null : () => _respondAll(confs, true),
                      icon: Icon(Icons.check, size: context.r(16)),
                      label: Text(l.confAcceptAll),
                    ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.rSafeInsets(left: 16, top: 4, right: 16, bottom: 16),
            itemCount: confs.length,
            itemBuilder: (context, i) => _ConfCard(
              key: ValueKey(confs[i].id),
              conf: confs[i],
              index: i,
              busy: _busy,
              holdEnabled: holdEnabled,
              hapticsEnabled: hapticsEnabled,
              onAccept: () => _respond([confs[i]], true),
              onReject: () => _respond([confs[i]], false),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single confirmation card with a stagger slide-in entrance.
class _ConfCard extends StatefulWidget {
  final Confirmation conf;
  final int index;
  final bool busy;
  final bool holdEnabled;
  final bool hapticsEnabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _ConfCard({
    super.key,
    required this.conf,
    required this.index,
    required this.busy,
    required this.holdEnabled,
    required this.hapticsEnabled,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_ConfCard> createState() => _ConfCardState();
}

class _ConfCardState extends State<_ConfCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    // Staggered entrance: 80ms per item.
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l) {
    switch (widget.conf.type) {
      case ConfirmationType.trade:
        return l.confTypeTrade;
      case ConfirmationType.marketListing:
        return l.confTypeMarket;
      case ConfirmationType.familyJoin:
        return l.confTypeFamilyJoin;
      case ConfirmationType.apiKey:
        return l.confTypeApiKey;
      case ConfirmationType.phoneChange:
        return l.confTypePhoneChange;
      case ConfirmationType.accountRecovery:
        return l.confTypeAccountRecovery;
      case ConfirmationType.featureOptOut:
        return l.confTypeFeatureOptOut;
      default:
        return l.confTypeOther;
    }
  }

  /// 安全敏感类型（改手机号/账户恢复/API key）用警示色，家庭组用正向色。
  Color _chipColor(AvaTokens t) {
    switch (widget.conf.type) {
      case ConfirmationType.trade:
        return t.accent;
      case ConfirmationType.familyJoin:
        return t.good;
      case ConfirmationType.apiKey:
      case ConfirmationType.phoneChange:
      case ConfirmationType.accountRecovery:
        return t.bad;
      default:
        return t.accent2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final c = widget.conf;
    final chipColor = _chipColor(t);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(26 * (1 - v), 0), child: child),
        );
      },
      child: Padding(
        padding: context.rInsets(bottom: 10),
        child: AvaPanel(
          padding: context.rInsets(all: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AvaChip(label: _typeLabel(l), color: chipColor),
                        if (c.typeName.isNotEmpty) ...[
                          SizedBox(width: context.r(8)),
                          Flexible(
                            child: Text(
                              c.typeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: t.muted, fontSize: context.r(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: context.r(8)),
                    Text(
                      c.headline.isEmpty ? _typeLabel(l) : c.headline,
                      style: TextStyle(color: t.text, fontSize: context.r(14)),
                    ),
                    if (c.summary.isNotEmpty) ...[
                      SizedBox(height: context.r(4)),
                      Text(
                        c.summary.join(' · '),
                        style: TextStyle(color: t.muted, fontSize: context.r(12)),
                      ),
                    ],
                  ],
                ),
              ),
              // Gaps compensate the invisible hit-target padding around the
              // visuals (5px per side on _RoundAction 48/38, 6px on the hold
              // button 48/36), keeping ~12 before and ~10 between visually.
              SizedBox(width: context.r(7)),
              _RoundAction(
                icon: Icons.close,
                color: t.bad,
                onTap: widget.busy ? null : widget.onReject,
              ),
              HoldToConfirmButton.round(
                icon: Icons.check,
                color: t.good,
                enabled: !widget.busy,
                holdEnabled: widget.holdEnabled,
                hapticsEnabled: widget.hapticsEnabled,
                semanticLabel: l.confAccept,
                onConfirmed: widget.onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _RoundAction({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    // 48dp tappable area around the 38dp visual box (a11y touch target).
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: SizedBox(
        width: context.r(48),
        height: context.r(48),
        child: Center(
          child: Container(
            width: context.r(38),
            height: context.r(38),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: color, size: context.r(18)),
          ),
        ),
      ),
    );
  }
}
