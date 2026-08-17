import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_offer.dart';
import '../../services/steam_api_client.dart' show CommunityAuthException;
import 'offer_card.dart';
import 'session_retry.dart';
import '../error_text.dart';

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
    with AutomaticKeepAliveClientMixin, SessionRetryState {
  _Segment _seg = _Segment.received;
  TradeOffersPage? _active; // received + sent 段共用的 active 拉取结果
  TradeOffersPage? _history;
  final Map<int, String> _personas = {};
  String? _expandedId;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _needsLogin = false; // session needs interactive sign-in, not a retry

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
      _needsLogin = false;
    });
    try {
      final historical = _seg == _Segment.history;
      final client = ref.read(tradeOffersClientProvider);
      final page = await fetchWithAutoRefresh(widget.account,
          () => client.fetch(widget.account, historical: historical));
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
      // 拉取期间用户可能切到了另一个尚无缓存的分段——那次 refresh 被防重入
      // 吞掉了,这里补拉一次,避免落在无 spinner 的假空态上。只在成功路径
      // 补拉:错误路径展示错误 + 重试,不会静默循环。
      final segMissing =
          _seg == _Segment.history ? _history == null : _active == null;
      if (segMissing) return refresh();
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

  /// Resolves partner persona names via the community miniprofile endpoint.
  /// Best-effort: only successful lookups land in the cache; failures keep
  /// the SteamID fallback. Lookups run in parallel — serially, N partners
  /// meant N round-trips before the last name filled in.
  Future<void> _loadPersonas(TradeOffersPage page) async {
    final client = ref.read(tradeOffersClientProvider);
    final ids = <int>{
      for (final o in page.received) o.partnerAccountId,
      for (final o in page.sent) o.partnerAccountId,
    }..removeAll(_personas.keys);
    await Future.wait([
      for (final id in ids)
        () async {
          final (name, _) = await client.miniProfile(id);
          if (mounted && name.isNotEmpty) {
            setState(() => _personas[id] = name);
          }
        }(),
    ]);
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
    if (_busy) return; // 同帧双发守卫(同 confirmations_tab._respond)
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    // accept 会抛异常(无 token、网络掉线、HTML 响应体解析失败)——不兜住
    // 的话 _busy 卡在 true,keep-alive 状态下整个页签的按钮永久死掉。
    try {
      final r = await ref
          .read(tradeOffersClientProvider)
          .accept(widget.account, offer);
      if (!mounted) return;
      if (r.success) {
        // Only point the user at the confirmations tab when a mobileconf
        // actually follows — otherwise they'd hunt for one that doesn't exist.
        messenger.showSnackBar(SnackBar(
            content: Text(r.needsMobileConfirmation
                ? l.offerAccepted
                : l.offerAcceptedNoConf)));
        if (r.needsMobileConfirmation) widget.onGoToConfirmations?.call();
        await refresh();
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(r.message == 'needauth'
              ? l.confNeedsLogin
              : l.offerActionFailed(r.message ?? '?')),
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(l.offerActionFailed(describeError(l, e)))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineOrCancel(TradeOffer offer) async {
    if (_busy) return; // 同帧双发守卫(同 confirmations_tab._respond)
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(tradeOffersClientProvider);
    final isSent = _seg == _Segment.sent;
    setState(() => _busy = true);
    try {
      // decline/cancel 把普通异常自吞返回 false;会话过期
      // (CommunityAuthException) 则抛出,在这里给出重新登录提示。
      // try/finally 保证 _busy 无论如何都复位。
      final ok = isSent
          ? await client.cancel(widget.account, offer.id)
          : await client.decline(widget.account, offer.id);
      if (!mounted) return;
      if (ok) {
        messenger.showSnackBar(SnackBar(
            content: Text(isSent ? l.offerCanceled : l.offerDeclined)));
        await refresh();
      } else {
        messenger
            .showSnackBar(SnackBar(content: Text(l.offerActionFailed('?'))));
      }
    } on CommunityAuthException {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l.confNeedsLogin)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Widget _body(AppLocalizations l, AvaTokens t) {
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
    final offers = _shown;
    if (offers.isEmpty) {
      return scrollableCentered(
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
      padding: context.rSafeInsets(left: 16, top: 8, right: 16, bottom: 16),
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
          // inEscrow 报价已被接受(物品暂挂中),再接受必失败 —— 只有
          // active 才给长按接受;拒绝保留(取消暂挂是合法操作)。
          onAccept: _seg == _Segment.received &&
                  offer.state == TradeOfferState.active
              ? () => _accept(offer)
              : null,
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
