import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/confirmation.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/confirmations_client.dart';
import '../services/session_manager.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

/// Design screen 06 — confirmations. Native JSON rendering (no WebView). Top
/// batch bar (accept all / reject all) + per-item cards with type chip, title,
/// summary and accept/reject. Items stagger in; acted items slide out.
class ConfirmationsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const ConfirmationsScreen({super.key, required this.account});

  @override
  ConsumerState<ConfirmationsScreen> createState() =>
      _ConfirmationsScreenState();
}

class _ConfirmationsScreenState extends ConsumerState<ConfirmationsScreen> {
  late final ConfirmationsClient _client;
  List<Confirmation>? _confs;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ConfirmationsClient(ref.read(apiClientProvider));
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _fetchWithAutoRefresh();
      if (!mounted) return;
      setState(() {
        _confs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ConfirmationAuthException
            ? AppLocalizations.of(context).confNeedsLogin
            : '$e';
      });
    }
  }

  /// Fetches confirmations; on a stale session (`needauth`) it transparently
  /// refreshes the access token from the refresh token and retries once. Only
  /// surfaces [ConfirmationAuthException] when there is no usable refresh token.
  Future<List<Confirmation>> _fetchWithAutoRefresh() async {
    try {
      return await _client.fetch(widget.account);
    } on ConfirmationAuthException {
      final refreshed = await SessionManager(ref.read(apiClientProvider))
          .refresh(widget.account.session);
      if (!refreshed) rethrow;
      await ref.read(appControllerProvider).value?.store.save();
      return await _client.fetch(widget.account);
    }
  }

  Future<void> _respond(List<Confirmation> confs, bool accept) async {
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
    await _refresh();
  }

  /// Batch accept/reject with an explicit confirmation dialog — acting on
  /// every pending confirmation must never be a single tap.
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
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final confs = _confs ?? const <Confirmation>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.confirmationsTitle),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: ScanlineOverlay(
        child: _buildBody(l, t, confs),
      ),
    );
  }

  Widget _buildBody(
      AppLocalizations l, AvaTokens t, List<Confirmation> confs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
              OutlinedButton(
                onPressed: _refresh,
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (confs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: t.good, size: context.r(44)),
            SizedBox(height: context.r(12)),
            Text(l.confirmationsEmpty),
          ],
        ),
      );
    }

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
              FilledButton.icon(
                onPressed: _busy ? null : () => _respondAll(confs, true),
                icon: Icon(Icons.check, size: context.r(16)),
                label: Text(l.confAcceptAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: context.rInsets(left: 16, top: 4, right: 16, bottom: 16),
            itemCount: confs.length,
            itemBuilder: (context, i) => _ConfCard(
              key: ValueKey(confs[i].id),
              conf: confs[i],
              index: i,
              busy: _busy,
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
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _ConfCard({
    super.key,
    required this.conf,
    required this.index,
    required this.busy,
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
      default:
        return l.confTypeOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final c = widget.conf;
    final isTrade = c.type == ConfirmationType.trade;
    final chipColor = isTrade ? t.accent : t.accent2;

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
              // Gaps compensate the 5px of invisible hit-target padding on
              // each side of _RoundAction (visually ~12 and ~10).
              SizedBox(width: context.r(7)),
              _RoundAction(
                icon: Icons.close,
                color: t.bad,
                onTap: widget.busy ? null : widget.onReject,
              ),
              _RoundAction(
                icon: Icons.check,
                color: t.good,
                onTap: widget.busy ? null : widget.onAccept,
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
