import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/models/confirmation.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/confirmations_client.dart';
import 'widgets/sda_panel.dart';
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
      final list = await _client.fetch(widget.account);
      if (!mounted) return;
      setState(() {
        _confs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
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
      AppLocalizations l, SdaTokens t, List<Confirmation> confs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: t.muted, size: 40),
              const SizedBox(height: 12),
              Text('${l.commonError}: $_error', textAlign: TextAlign.center),
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
            Icon(Icons.check_circle_outline, color: t.good, size: 44),
            const SizedBox(height: 12),
            Text(l.confirmationsEmpty),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Batch bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.confPending(confs.length),
                  style: TextStyle(color: t.text, fontSize: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _respond(confs, false),
                icon: const Icon(Icons.close, size: 16),
                label: Text(l.confRejectAll),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : () => _respond(confs, true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l.confAcceptAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
    final t = Theme.of(context).extension<SdaTokens>()!;
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
        padding: const EdgeInsets.only(bottom: 10),
        child: SdaPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SdaChip(label: _typeLabel(l), color: chipColor),
                        if (c.typeName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              c.typeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: t.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.headline.isEmpty ? _typeLabel(l) : c.headline,
                      style: TextStyle(color: t.text, fontSize: 14),
                    ),
                    if (c.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.summary.join(' · '),
                        style: TextStyle(color: t.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RoundAction(
                icon: Icons.close,
                color: t.bad,
                onTap: widget.busy ? null : widget.onReject,
              ),
              const SizedBox(width: 8),
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
    final t = Theme.of(context).extension<SdaTokens>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
