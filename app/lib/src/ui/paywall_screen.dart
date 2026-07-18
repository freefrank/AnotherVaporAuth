import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/channel.dart';
import '../core/entitlement.dart';
import '../services/entitlement_store.dart';
import '../services/pro_actions.dart';

/// Afdian sponsor page (cn channel; ifdian.net is Afdian's
/// mainland-reachable domain).
const kAfdianPageUrl = 'https://ifdian.net/a/anothervaporauth';

/// ProResult / worker error code → user copy. Codes without an arm fall to
/// proErrGeneric with the raw slug — every code the worker can emit at launch
/// must stay out of that bucket.
@visibleForTesting
String paywallErrorText(AppLocalizations l, String code) => switch (code) {
      'canceled' => l.proErrCanceled,
      'network' => l.proErrNetwork,
      'not_configured' || 'unavailable' => l.proErrNotConfigured,
      'no_subscription' => l.proErrNoSubscription,
      'order_bound' => l.proErrOrderBound,
      // The worker emits order_invalid; the other two names predate it.
      'order_invalid' || 'order_not_found' || 'plan_mismatch' =>
        l.proErrOrderNotFound,
      'device_revoked' => l.proErrDeviceRevoked,
      'no_vip' || 'not_earned' => l.proErrNoVip,
      'code_invalid' => l.proErrCodeInvalid,
      // Pre per-class-slot workers only; kept for rollout overlap.
      'code_redeemed' => l.proErrCodeRedeemed,
      'code_activation_limit' => l.proErrCodeActivationLimit,
      'revoked' || 'entitlement_ended' => l.proErrRevoked,
      _ => l.proErrGeneric(code),
    };

String _deviceClassName(AppLocalizations l, String cls) => switch (cls) {
      'android' => l.proDeviceClassAndroid,
      'windows' => l.proDeviceClassWindows,
      'linux' => l.proDeviceClassLinux,
      'macos' => l.proDeviceClassMacos,
      // Unknown class (newer worker vocabulary): the raw slug beats hiding
      // an occupied slot.
      _ => cls,
    };

/// "已激活：Android · Windows（本机）" — the status card's activation row.
@visibleForTesting
String paywallActivationsLine(
    AppLocalizations l, List<EntitlementActivation> activations) {
  final parts = activations.map((a) => a.thisDevice
      ? l.proStatusClassThisDevice(_deviceClassName(l, a.deviceClass))
      : _deviceClassName(l, a.deviceClass));
  return l.proStatusActivations(parts.join(' · '));
}

/// "占用中：Android（3 天前）" — appended to the code_activation_limit
/// refusal so the user sees which class holds the slot and since when,
/// instead of only the static "switched devices too often" copy.
@visibleForTesting
String paywallSlotOccupiedLine(AppLocalizations l,
    List<EntitlementActivation> activations, DateTime now) {
  String when(DateTime at) {
    final days = now.difference(at).inDays;
    return days <= 0 ? l.proSlotToday : l.proSlotDaysAgo(days);
  }

  final parts = activations.map(
      (a) => l.proSlotEntry(_deviceClassName(l, a.deviceClass), when(a.activatedAt)));
  return l.proErrSlotOccupied(parts.join(' · '));
}

/// AVA Pro paywall: status, perks, and the channel's unlock paths.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _orderCtrl = TextEditingController();
  final _betaCtrl = TextEditingController();
  bool _busy = false;

  /// Occupied device-class slots, fetched best-effort when Pro is active.
  /// Null (fetch pending/failed) renders nothing — never blocks the paywall.
  List<EntitlementActivation>? _activations;

  // A successful redeem both calls _loadActivations directly and flips
  // proStatus free→pro (which trips the listener), so guard against the two
  // firing the status() network call concurrently.
  bool _loadingActivations = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadActivations);
  }

  Future<void> _loadActivations() async {
    if (_loadingActivations) return;
    _loadingActivations = true;
    try {
      final token = ref.read(entitlementTokenProvider);
      if (token == null || ref.read(proStatusProvider) == ProStatus.free) {
        return;
      }
      final status = await ref.read(entitlementApiProvider).status(token.raw);
      if (mounted) setState(() => _activations = status.activations);
    } catch (_) {
      // Informative row only; any failure leaves the card as-is.
    } finally {
      _loadingActivations = false;
    }
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _betaCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ProResult> Function(ProActions a) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action(ref.read(proActionsProvider));
      if (!mounted) return;
      // A success changes the slot map (this device just claimed one):
      // refresh the status card's activation row without a screen reopen.
      if (result.ok) _loadActivations();
      final l = AppLocalizations.of(context);
      var text = result.ok
          ? l.proResultSuccess
          : paywallErrorText(l, result.code ?? 'unknown');
      // code_activation_limit carries the occupied slots — show them.
      if (!result.ok && (result.activations?.isNotEmpty ?? false)) {
        text = '$text\n${paywallSlotOccupiedLine(
            l, result.activations!, ref.read(clockProvider)())}';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLine(AppLocalizations l) {
    final token = ref.watch(entitlementTokenProvider);
    final status = ref.watch(proStatusProvider);
    switch (status) {
      case ProStatus.free:
        return l.proStatusFree;
      case ProStatus.vip:
        return l.proStatusVip(_date(token?.proUntil));
      case ProStatus.pro:
        final until = token?.proUntil;
        return until == null ? l.proStatusLifetime : l.proStatusPro(_date(until));
    }
  }

  String _date(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    // _loadActivations bails while free — a later flip to a pro tier
    // (in-screen redeem, background refresh) must re-trigger the fetch.
    ref.listen(proStatusProvider, (prev, next) {
      if (prev == ProStatus.free && next != ProStatus.free) {
        _loadActivations();
      }
    });
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final isPlay = avaChannel == AvaChannel.play;

    return Scaffold(
      appBar: AppBar(title: Text(l.paywallTitle)),
      body: SafeArea(
        child: ListView(
          padding: context.rInsets(h: 16, v: 12),
          children: [
            _card(context, t,
                title: _statusLine(l),
                description: l.paywallPerksTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activations?.isNotEmpty ?? false)
                      Padding(
                        padding: context.rInsets(v: 3),
                        child: Text(paywallActivationsLine(l, _activations!),
                            style: TextStyle(
                                fontSize: context.r(12.5), color: t.muted)),
                      ),
                    _perk(context, t, l.paywallPerkSkins),
                    if (isPlay) _perk(context, t, l.paywallPerkNoAds),
                    _perk(context, t, l.paywallPerkFuture),
                  ],
                )),
            if (isPlay)
              _card(context, t,
                  title: l.paywallPlayTitle,
                  child: Wrap(
                    spacing: context.r(8),
                    runSpacing: context.r(8),
                    children: [
                      _button(context, t, l.paywallSubscribe, _busy,
                          () => _run((a) => a.subscribeViaPlay())),
                      _button(context, t, l.paywallWatchAd, _busy,
                          () => _run((a) => a.watchRewarded())),
                      _button(context, t, l.paywallRestore, _busy,
                          () => _run((a) => a.restoreViaPlay()),
                          filled: false),
                    ],
                  ))
            else
              _card(context, t,
                  title: l.paywallCnTitle,
                  description: l.paywallAfdianIntro,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _button(context, t, l.paywallOpenAfdian, false, () {
                        launchUrl(Uri.parse(kAfdianPageUrl),
                            mode: LaunchMode.externalApplication);
                      }, filled: false),
                      SizedBox(height: context.r(10)),
                      _redeemRow(context, t, _orderCtrl, l.paywallOrderHint,
                          l.paywallRedeem,
                          () => _run((a) => a.redeemAfdian(_orderCtrl.text))),
                    ],
                  )),
            _card(context, t,
                title: l.paywallBetaTitle,
                description: l.paywallBetaIntro,
                child: _redeemRow(context, t, _betaCtrl, l.paywallBetaHint,
                    l.paywallBetaRedeem,
                    () => _run((a) => a.redeemBeta(_betaCtrl.text)))),
          ],
        ),
      ),
    );
  }

  Widget _redeemRow(BuildContext context, AvaTokens t,
      TextEditingController ctrl, String hint, String label, VoidCallback go) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint, isDense: true),
        ),
      ),
      SizedBox(width: context.r(8)),
      _button(context, t, label, _busy, go),
    ]);
  }

  Widget _perk(BuildContext context, AvaTokens t, String text) => Padding(
        padding: context.rInsets(v: 3),
        child: Row(children: [
          Icon(Icons.check, size: context.r(16), color: t.accent),
          SizedBox(width: context.r(8)),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: context.r(13), color: t.text))),
        ]),
      );

  Widget _card(BuildContext context, AvaTokens t,
      {required String title, String? description, required Widget child}) {
    return Container(
      margin: context.rInsets(v: 6),
      padding: context.rInsets(h: 14, v: 12),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: context.r(15),
                  fontWeight: FontWeight.w600,
                  color: t.text)),
          if (description != null) ...[
            SizedBox(height: context.r(4)),
            Text(description,
                style:
                    TextStyle(fontSize: context.r(12.5), color: t.muted)),
          ],
          SizedBox(height: context.r(10)),
          child,
        ],
      ),
    );
  }

  Widget _button(BuildContext context, AvaTokens t, String label, bool busy,
      VoidCallback onTap,
      {bool filled = true}) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        padding: context.rInsets(h: 16, v: 10),
        decoration: BoxDecoration(
          color: filled ? t.accent : t.panel2,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border.all(
              color: filled ? t.accent : t.borderColor, width: t.borderWidth),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? const Color(0xFF06060F) : t.text,
            fontSize: context.r(13),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
