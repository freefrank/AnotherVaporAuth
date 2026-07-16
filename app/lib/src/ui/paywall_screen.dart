import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/channel.dart';
import '../core/entitlement.dart';
import '../services/pro_actions.dart';

/// Afdian sponsor page (cn channel; ifdian.net is Afdian's
/// mainland-reachable domain).
const kAfdianPageUrl = 'https://ifdian.net/a/anothervaporauth';

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
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.ok
            ? l.proResultSuccess
            : _errorText(l, result.code ?? 'unknown')),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(AppLocalizations l, String code) => switch (code) {
        'canceled' => l.proErrCanceled,
        'network' => l.proErrNetwork,
        'not_configured' || 'unavailable' => l.proErrNotConfigured,
        'no_subscription' => l.proErrNoSubscription,
        'order_bound' => l.proErrOrderBound,
        'order_not_found' || 'plan_mismatch' => l.proErrOrderNotFound,
        'device_revoked' => l.proErrDeviceRevoked,
        'no_vip' || 'not_earned' => l.proErrNoVip,
        _ => l.proErrGeneric(code),
      };

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
