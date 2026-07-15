import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_offer.dart';
import '../../services/session_manager.dart';
import 'offer_card.dart';

/// 报价页签：收到 / 发出 / 历史 三段。卡片可展开（双方物品 + 警示条），
/// 接受走长按确认，拒绝/取消即点即行。Hosted inside PendingScreen。
class TradeOffersTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;

  /// Reports the pending received-offer count to the parent (tab badge).
  final ValueChanged<int>? onCount;

  /// Jumps to the confirmations tab after an accept that needs mobileconf.
  final VoidCallback? onGoToConfirmations;
  const TradeOffersTab({
    super.key,
    required this.account,
    this.onCount,
    this.onGoToConfirmations,
  });

  @override
  ConsumerState<TradeOffersTab> createState() => TradeOffersTabState();
}

enum _Segment { received, sent, history }

/// Public so PendingScreen can delegate the AppBar refresh action via a
/// GlobalKey. Kept alive across tab switches (same rationale as
/// [ConfirmationsTabState]): re-creating the state would re-fetch on every
/// switch and drop segment/expansion/scroll state.
class TradeOffersTabState extends ConsumerState<TradeOffersTab>
    with AutomaticKeepAliveClientMixin {
  _Segment _seg = _Segment.received;
  TradeOffersPage? _active; // received + sent 段共用的 active 拉取结果
  TradeOffersPage? _history;
  final Map<int, String> _personas = {};
  String? _expandedId;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (_loading) return; // AppBar 按钮 + 下拉可并发触发,防重入
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final historical = _seg == _Segment.history;
      final page = await _fetchWithAutoRefresh(historical);
      if (!mounted) return;
      setState(() {
        if (historical) {
          _history = page;
        } else {
          _active = page;
        }
        _loading = false;
      });
      final active = _active;
      if (active != null) {
        widget.onCount?.call(active.received
            .where((o) => o.state == TradeOfferState.active)
            .length);
      }
      _loadPersonas(page);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Fetches offers; on failure it refreshes the access token from the
  /// refresh token and retries once (same pattern as ConfirmationsTab's
  /// `_fetchWithAutoRefresh`). Rethrows when the refresh doesn't help.
  Future<TradeOffersPage> _fetchWithAutoRefresh(bool historical) async {
    final client = ref.read(tradeOffersClientProvider);
    try {
      return await client.fetch(widget.account, historical: historical);
    } catch (_) {
      final refreshed = await SessionManager(ref.read(apiClientProvider))
          .refresh(widget.account.session);
      if (!refreshed) rethrow;
      // Guard: the tab may have been disposed while the token refresh was in
      // flight — reading a disposed ref throws and the save would be lost.
      if (mounted) {
        await ref.read(appControllerProvider).value?.store.save();
      }
      return await client.fetch(widget.account, historical: historical);
    }
  }

  /// Resolves partner persona names via the community miniprofile endpoint.
  /// Best-effort: only successful lookups land in the cache; failures keep
  /// the SteamID fallback.
  Future<void> _loadPersonas(TradeOffersPage page) async {
    final client = ref.read(tradeOffersClientProvider);
    final ids = <int>{
      for (final o in page.received) o.partnerAccountId,
      for (final o in page.sent) o.partnerAccountId,
    }..removeAll(_personas.keys);
    for (final id in ids) {
      final (name, _) = await client.miniProfile(id);
      if (!mounted) return;
      if (name.isNotEmpty) setState(() => _personas[id] = name);
    }
  }

  /// The offers of the current segment, filtered/sorted for display.
  List<TradeOffer> get _shown {
    switch (_seg) {
      case _Segment.received:
        return (_active?.received ?? const [])
            .where((o) =>
                o.state == TradeOfferState.active ||
                o.state == TradeOfferState.inEscrow)
            .toList();
      case _Segment.sent:
        return (_active?.sent ?? const [])
            .where((o) =>
                o.state == TradeOfferState.active ||
                o.state == TradeOfferState.needsConfirmation)
            .toList();
      case _Segment.history:
        final h = _history;
        if (h == null) return const [];
        return [...h.received, ...h.sent]
          ..sort((a, b) => b.timeUpdated.compareTo(a.timeUpdated));
    }
  }

  Future<void> _accept(TradeOffer offer) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await ref
        .read(tradeOffersClientProvider)
        .accept(widget.account, offer);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.success) {
      messenger.showSnackBar(SnackBar(content: Text(l.offerAccepted)));
      if (r.needsMobileConfirmation) widget.onGoToConfirmations?.call();
      await refresh();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(r.message == 'needauth'
            ? l.confNeedsLogin
            : l.offerActionFailed(r.message ?? '?')),
      ));
    }
  }

  Future<void> _declineOrCancel(TradeOffer offer) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(tradeOffersClientProvider);
    final isSent = _seg == _Segment.sent;
    setState(() => _busy = true);
    final ok = isSent
        ? await client.cancel(widget.account, offer.id)
        : await client.decline(widget.account, offer.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      messenger.showSnackBar(SnackBar(
          content: Text(isSent ? l.offerCanceled : l.offerDeclined)));
      await refresh();
    } else {
      messenger
          .showSnackBar(SnackBar(content: Text(l.offerActionFailed('?'))));
    }
  }

  void _switchSeg(_Segment seg) {
    if (seg == _seg) return;
    setState(() {
      _seg = seg;
      _expandedId = null;
      _error = null;
    });
    // 目标段无缓存才拉取;有缓存直接展示,下拉可强制刷新。
    final hasCache = seg == _Segment.history ? _history != null : _active != null;
    if (!hasCache) refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin contract.
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;

    return Column(
      children: [
        Padding(
          padding: context.rInsets(left: 16, top: 12, right: 16, bottom: 4),
          child: SegmentedButton<_Segment>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: _Segment.received, label: Text(l.offersSegReceived)),
              ButtonSegment(value: _Segment.sent, label: Text(l.offersSegSent)),
              ButtonSegment(
                  value: _Segment.history, label: Text(l.offersSegHistory)),
            ],
            selected: {_seg},
            onSelectionChanged: (s) => _switchSeg(s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: _body(l, t),
          ),
        ),
      ],
    );
  }

  /// Wraps [child] in a scrollable that fills the viewport and centers it —
  /// RefreshIndicator needs a scrollable to trigger (same as ConfirmationsTab).
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
    if (_loading) {
      // Non-scrollable on purpose: pull-to-refresh is pointless mid-load.
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _scrollableCentered(
        Padding(
          padding: context.rInsets(all: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: t.muted, size: context.r(40)),
              SizedBox(height: context.r(12)),
              Text('${l.commonError}: $_error', textAlign: TextAlign.center),
              SizedBox(height: context.r(16)),
              OutlinedButton(onPressed: refresh, child: Text(l.commonRetry)),
            ],
          ),
        ),
      );
    }
    final offers = _shown;
    if (offers.isEmpty) {
      return _scrollableCentered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, color: t.muted, size: context.r(44)),
            SizedBox(height: context.r(12)),
            Text(l.offersEmpty),
          ],
        ),
      );
    }
    final holdEnabled = ref.watch(holdConfirmProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: context.rInsets(left: 16, top: 8, right: 16, bottom: 16),
      itemCount: offers.length,
      itemBuilder: (context, i) {
        final offer = offers[i];
        final actionable = _seg != _Segment.history;
        return OfferCard(
          key: ValueKey(offer.id),
          offer: offer,
          expanded: _expandedId == offer.id,
          busy: _busy,
          personaName: _personas[offer.partnerAccountId] ?? '',
          onToggle: () => setState(() =>
              _expandedId = _expandedId == offer.id ? null : offer.id),
          onAccept:
              _seg == _Segment.received ? () => _accept(offer) : null,
          onDeclineOrCancel:
              actionable ? () => _declineOrCancel(offer) : null,
          declineLabel:
              _seg == _Segment.sent ? l.offerCancel : l.offerDecline,
          holdEnabled: holdEnabled,
          hapticsEnabled: hapticsEnabled,
        );
      },
    );
  }
}
