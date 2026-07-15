import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/trade_offer.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';

/// 可展开的报价卡（spec 方案 C）：收起 = 对方 + 时间 + 摘要行；
/// 展开 = 双方物品缩略图 + 警示条 + 拒绝/长按接受。
class OfferCard extends StatelessWidget {
  final TradeOffer offer;
  final bool expanded;
  final bool busy;
  final String personaName; // '' → 显示 SteamID
  final VoidCallback onToggle;
  final VoidCallback? onAccept; // null → 不显示接受（发出/历史）
  final VoidCallback? onDeclineOrCancel;
  final String declineLabel;
  final bool holdEnabled; // 设置开关（Task 8b providers）
  final bool hapticsEnabled;

  const OfferCard({
    super.key,
    required this.offer,
    required this.expanded,
    required this.busy,
    required this.personaName,
    required this.onToggle,
    required this.declineLabel,
    required this.holdEnabled,
    required this.hapticsEnabled,
    this.onAccept,
    this.onDeclineOrCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final who =
        personaName.isNotEmpty ? personaName : '${offer.partnerSteamId}';

    return Padding(
      padding: context.rInsets(bottom: 10),
      child: AvaPanel(
        padding: context.rInsets(all: 14),
        child: InkWell(
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text, fontSize: context.r(14))),
                  ),
                  Text(_age(offer.timeUpdated),
                      style:
                          TextStyle(color: t.muted, fontSize: context.r(11))),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: t.muted, size: context.r(18)),
                ],
              ),
              SizedBox(height: context.r(6)),
              // 摘要行（收起态核心信息）。
              Text(
                [
                  '↓ ${offer.itemsToReceive.length}',
                  '↑ ${offer.itemsToGive.length}',
                  if (offer.isGift) '🎁',
                ].join('  ·  '),
                style: TextStyle(color: t.muted, fontSize: context.r(12)),
              ),
              if (expanded) ...[
                SizedBox(height: context.r(10)),
                if (offer.itemsToReceive.isNotEmpty)
                  _assetRow(context, t, l.offerReceiveLabel,
                      offer.itemsToReceive, t.good),
                if (offer.itemsToGive.isNotEmpty)
                  _assetRow(
                      context, t, l.offerGiveLabel, offer.itemsToGive, t.bad),
                if (offer.isGift) _banner(context, t.good, l.offerGift),
                if (offer.isOneSidedGive)
                  _banner(context, t.bad, l.offerOneSided),
                // 只在报价确实处于暂挂状态时提示 —— history 段里已完成的
                // 报价留着 escrow_end_date,横幅会误导。
                if (offer.escrowEndDate > 0 &&
                    offer.state == TradeOfferState.inEscrow)
                  _banner(context, t.accent2, l.offerEscrow),
                SizedBox(height: context.r(10)),
                Row(
                  children: [
                    if (onDeclineOrCancel != null)
                      OutlinedButton(
                        onPressed: busy ? null : onDeclineOrCancel,
                        child: Text(declineLabel),
                      ),
                    const Spacer(),
                    if (onAccept != null)
                      HoldToConfirmButton(
                        label: l.offerAcceptHold,
                        color: t.good,
                        enabled: !busy,
                        holdEnabled: holdEnabled,
                        hapticsEnabled: hapticsEnabled,
                        onConfirmed: onAccept!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetRow(BuildContext context, AvaTokens t, String label,
      List<TradeAsset> assets, Color accent) {
    return Padding(
      padding: context.rInsets(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: accent, fontSize: context.r(11))),
          SizedBox(height: context.r(4)),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final a in assets)
                Tooltip(
                  message: a.name,
                  child: Container(
                    width: context.r(40),
                    height: context.r(40),
                    decoration: BoxDecoration(
                      color: t.muted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _rarityColor(t, a.nameColor)),
                    ),
                    child: a.iconUrl.isEmpty
                        ? Icon(Icons.inventory_2_outlined,
                            color: t.muted, size: context.r(18))
                        : Image.network(
                            a.iconUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                                Icons.inventory_2_outlined,
                                color: t.muted,
                                size: context.r(18)),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Steam 的 name_color 是不带 # 的 6 位 hex —— 非法值(空串、奇怪长度、
  /// 非 hex 字符)一律回退到弱化边框，绝不 throw。
  static Color _rarityColor(AvaTokens t, String nameColor) {
    final v = nameColor.length == 6
        ? int.tryParse('FF$nameColor', radix: 16)
        : null;
    return v != null ? Color(v) : t.muted.withValues(alpha: 0.4);
  }

  Widget _banner(BuildContext context, Color color, String text) => Container(
        margin: context.rInsets(top: 4),
        padding: context.rInsets(left: 8, top: 4, right: 8, bottom: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: context.r(11))),
      );

  static String _age(int epoch) {
    if (epoch == 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}
