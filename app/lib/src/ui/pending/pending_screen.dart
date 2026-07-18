import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/models/steam_guard_account.dart';
import '../widgets/scanline_overlay.dart';
import 'confirmations_tab.dart';
import 'trade_offers_tab.dart';

/// 待办中心：确认 / 报价两页签（家庭组邀请已迁到账户长按菜单的家庭组页）。
/// 页签角标 = 各 tab 拉取成功后上报的待处理数。
class PendingScreen extends StatefulWidget {
  final SteamGuardAccount account;
  const PendingScreen({super.key, required this.account});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  // Lets the AppBar refresh action delegate to the active tab —
  // desktop mouse users can't trigger the drag-only RefreshIndicator.
  final _confTabKey = GlobalKey<ConfirmationsTabState>();
  final _offersTabKey = GlobalKey<TradeOffersTabState>();
  int? _confCount;
  int? _offerCount;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _tab(String label, int? count) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Badge(label: Text('$count')),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pendingTitle),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            // Always enabled; dispatches to the active tab.
            onPressed: () {
              if (_tabs.index == 0) _confTabKey.currentState?.refresh();
              if (_tabs.index == 1) _offersTabKey.currentState?.refresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            _tab(l.pendingTabConfirmations, _confCount),
            _tab(l.pendingTabOffers, _offerCount),
          ],
        ),
      ),
      body: ScanlineOverlay(
        child: TabBarView(
          controller: _tabs,
          children: [
            ConfirmationsTab(
              key: _confTabKey,
              account: widget.account,
              onCount: (n) => setState(() => _confCount = n),
            ),
            TradeOffersTab(
              key: _offersTabKey,
              account: widget.account,
              onCount: (n) => setState(() => _offerCount = n),
              onGoToConfirmations: () {
                _tabs.animateTo(0);
                // The confirmations tab is keep-alive and never refetches on
                // its own — without this the user lands on stale data (often
                // the "all done" empty state) right after being told to
                // confirm the accepted trade there.
                _confTabKey.currentState?.refresh();
              },
            ),
          ],
        ),
      ),
    );
  }
}
