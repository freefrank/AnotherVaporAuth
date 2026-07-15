// 占位页签 —— Task 10 实装报价列表。
import 'package:flutter/material.dart';

import '../../core/models/steam_guard_account.dart';

class TradeOffersTab extends StatelessWidget {
  final SteamGuardAccount account;
  final ValueChanged<int>? onCount;
  final VoidCallback? onGoToConfirmations;
  const TradeOffersTab({
    super.key,
    required this.account,
    this.onCount,
    this.onGoToConfirmations,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
