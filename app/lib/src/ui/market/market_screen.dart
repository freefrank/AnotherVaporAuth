import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_item.dart';
import '../../core/protocol/inventory_client.dart';
import 'sell_sheet.dart';

/// Inventory browser + market listings for one account.
class MarketScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const MarketScreen({super.key, required this.account});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  InventoryOverview? _overview;
  String? _error;
  InventoryGame? _game;

  // Identical items are stacked (grouped by classid_instanceid) for display and
  // batch selling.
  final _stacks = <ItemStack>[];
  final _stackByKey = <String, ItemStack>{};
  final _scroll = ScrollController();
  String? _lastAssetId;
  bool _moreItems = false;
  bool _loadingItems = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadOverview();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() => _error = null);
    try {
      // Make sure the session is fresh before hitting the community endpoints.
      await ref.read(autoLoginProvider).ensureSession(widget.account);
      final ov = await ref.read(inventoryClientProvider).overview(widget.account);
      if (!mounted) return;
      setState(() => _overview = ov);
      if (ov.games.isNotEmpty) _selectGame(ov.games.first);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _selectGame(InventoryGame g) async {
    setState(() {
      _game = g;
      _stacks.clear();
      _stackByKey.clear();
      _lastAssetId = null;
      _moreItems = false;
    });
    await _loadItems();
  }

  Future<void> _loadItems() async {
    if (_loadingItems || _game == null) return;
    setState(() => _loadingItems = true);
    try {
      final page = await ref.read(inventoryClientProvider).items(
            widget.account,
            _game!.appid,
            _game!.contextId,
            startAssetId: _lastAssetId,
          );
      if (!mounted) return;
      setState(() {
        for (final it in page.items) {
          final key = '${it.classId}_${it.instanceId}';
          final existing = _stackByKey[key];
          if (existing != null) {
            existing.assetIds.add(it.assetId);
          } else {
            final s = ItemStack(item: it, assetIds: [it.assetId]);
            _stackByKey[key] = s;
            _stacks.add(s);
          }
        }
        _lastAssetId = page.lastAssetId;
        _moreItems = page.more;
      });
    } catch (_) {
      // leave what we have
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  void _onScroll() {
    if (_moreItems &&
        !_loadingItems &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadItems();
    }
  }

  Future<void> _openSell(ItemStack stack) async {
    final ov = _overview;
    if (ov == null) return;
    final listed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellSheet(
        account: widget.account,
        item: stack.item,
        assetIds: List.of(stack.assetIds),
        wallet: ov.wallet,
      ),
    );
    if (listed == true && mounted) {
      setState(() {}); // a listing was created; refresh view state
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.accountName ?? l.actionMarket),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.marketTabInventory),
            Tab(text: l.marketTabListings),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _inventoryTab(l),
          _MyListingsTab(account: widget.account),
        ],
      ),
    );
  }

  Widget _inventoryTab(AppLocalizations l) {
    if (_error != null) {
      return _Centered(
        text: _error!,
        action: TextButton(onPressed: _loadOverview, child: Text(l.commonRetry)),
      );
    }
    final ov = _overview;
    if (ov == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _gamePicker(ov.games),
        Expanded(child: _itemGrid(l)),
      ],
    );
  }

  Widget _gamePicker(List<InventoryGame> games) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return SizedBox(
      height: context.r(64),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: context.rInsets(h: 12, v: 10),
        itemCount: games.length,
        separatorBuilder: (_, _) => SizedBox(width: context.r(8)),
        itemBuilder: (context, i) {
          final g = games[i];
          final selected = _game?.appid == g.appid && _game?.contextId == g.contextId;
          return InkWell(
            onTap: () => _selectGame(g),
            borderRadius: BorderRadius.circular(t.radiusSm),
            child: Container(
              padding: context.rInsets(h: 10, v: 6),
              decoration: BoxDecoration(
                color: selected ? t.panel2 : Colors.transparent,
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(
                    color: selected ? t.accent : t.line,
                    width: t.borderWidth),
              ),
              child: Row(
                children: [
                  if (g.iconUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      child: Image.network(g.iconUrl,
                          width: context.r(28),
                          height: context.r(28),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    ),
                  SizedBox(width: context.r(8)),
                  Text('${g.name}  ',
                      style: TextStyle(
                          color: selected ? t.text : t.muted,
                          fontSize: context.r(13))),
                  Text('${g.itemCount}',
                      style: TextStyle(
                          color: t.accent, fontSize: context.r(12))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemGrid(AppLocalizations l) {
    if (_stacks.isEmpty && !_loadingItems) {
      return _Centered(text: l.marketNoItems);
    }
    return GridView.builder(
      controller: _scroll,
      padding: context.rInsets(all: 12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: context.r(110),
        mainAxisSpacing: context.r(10),
        crossAxisSpacing: context.r(10),
        childAspectRatio: 0.82,
      ),
      itemCount: _stacks.length,
      itemBuilder: (context, i) => _ItemTile(
        stack: _stacks[i],
        onTap: _stacks[i].item.marketable ? () => _openSell(_stacks[i]) : null,
      ),
    );
  }
}

/// A group of identical inventory items (one tile, one sell sheet).
class ItemStack {
  final InventoryItem item;
  final List<String> assetIds;
  ItemStack({required this.item, required this.assetIds});
  int get count => assetIds.length;
}

class _ItemTile extends StatelessWidget {
  final ItemStack stack;
  final VoidCallback? onTap;
  const _ItemTile({required this.stack, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final l = AppLocalizations.of(context);
    final item = stack.item;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Opacity(
        opacity: item.marketable ? 1 : 0.45,
        child: Stack(
          children: [
            Container(
              padding: context.rInsets(all: 6),
              decoration: BoxDecoration(
                color: t.panel2.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(color: t.line, width: t.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: item.iconUrl.isEmpty
                        ? const SizedBox.shrink()
                        : Image.network(item.iconUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                  SizedBox(height: context.r(4)),
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: t.text, fontSize: context.r(10.5))),
                  if (!item.marketable)
                    Text(l.marketNotMarketable,
                        style:
                            TextStyle(color: t.muted, fontSize: context.r(9))),
                ],
              ),
            ),
            if (stack.count > 1)
              Positioned(
                top: context.r(4),
                right: context.r(4),
                child: Container(
                  padding: context.rInsets(h: 6, v: 2),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Text('×${stack.count}',
                      style: TextStyle(
                          color: const Color(0xFF06060F),
                          fontSize: context.r(11),
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyListingsTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const _MyListingsTab({required this.account});

  @override
  ConsumerState<_MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends ConsumerState<_MyListingsTab> {
  late Future<List<MarketListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MarketListing>> _load() =>
      ref.read(marketClientProvider).myListings(widget.account);

  void _refresh() => setState(() => _future = _load());

  Future<void> _cancel(MarketListing l) async {
    final ok = await ref.read(marketClientProvider).cancel(widget.account, l.listingId);
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? loc.marketCancelled : loc.commonError)));
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    return FutureBuilder<List<MarketListing>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snap.data ?? const <MarketListing>[];
        if (listings.isEmpty) return _Centered(text: l.marketNoListings);
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: context.rInsets(all: 12),
            itemCount: listings.length,
            separatorBuilder: (_, _) => Divider(color: t.line, height: context.r(1)),
            itemBuilder: (context, i) {
              final lst = listings[i];
              return ListTile(
                leading: lst.iconUrl.isEmpty
                    ? null
                    : Image.network(lst.iconUrl, width: context.r(40)),
                title: Text(lst.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${l.marketBuyerPays}: ${_money(lst.buyerPrice)}',
                    style: TextStyle(color: t.accent)),
                trailing: IconButton(
                  tooltip: l.marketCancel,
                  icon: Icon(Icons.close, color: t.bad),
                  onPressed: () => _cancel(lst),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _money(int minor) => (minor / 100).toStringAsFixed(2);
}

class _Centered extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Centered({required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      );
}
