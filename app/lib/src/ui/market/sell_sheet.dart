import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/market_fees.dart';
import '../../core/models/confirmation.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_item.dart';
import '../../core/protocol/confirmations_client.dart';
import '../../services/steam_api_client.dart';

/// The market-listing confirmations in [latest] that are NOT in the
/// [preExistingCreatorIds] snapshot — i.e. the ones created since the snapshot.
/// Auto-confirm uses this so it only ever approves the current listing, never
/// a market confirmation the user already had pending.
@visibleForTesting
List<Confirmation> newMarketConfirmations(
  Set<String> preExistingCreatorIds,
  List<Confirmation> latest,
) {
  return latest
      .where(
        (c) =>
            c.type == ConfirmationType.marketListing &&
            !preExistingCreatorIds.contains(c.creatorId),
      )
      .toList();
}

/// Parses a user-entered price into wallet minor units. Either '.' or ',' is
/// accepted as the decimal separator. Returns null for empty/ambiguous input:
/// mixed separators ('1.234,56'), a repeated separator ('1,234,567'), or a
/// separator followed by 3+ digits ('1,234', '1.234' — thousands-looking;
/// prices carry at most 2 decimals). Ambiguity must surface an error, never a
/// silently mispriced listing.
@visibleForTesting
int? parsePriceToMinor(String s) {
  final t = s.trim();
  final seps = t.split('').where((c) => c == '.' || c == ',').length;
  if (seps > 1) return null;
  final sep = seps == 0 ? -1 : t.lastIndexOf(RegExp(r'[.,]'));
  if (sep >= 0 && t.length - sep - 1 >= 3) return null;
  final v = double.tryParse(t.replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  return (v * 100).round();
}

/// True only when the whole batch for this listing was actually approved.
@visibleForTesting
bool autoConfirmSucceeded(BatchResult r) => r.failed == 0 && r.ok > 0;

/// Bottom sheet to list an inventory item for sale: market price + trend,
/// two linked price fields (you receive ⇄ buyer pays) computed with Steam's
/// live fees, and an optional auto-confirm. Pops `true` once a listing is made.
class SellSheet extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final InventoryItem item;
  final List<String> assetIds; // all identical copies available to list
  final WalletInfo wallet;
  const SellSheet({
    super.key,
    required this.account,
    required this.item,
    required this.assetIds,
    required this.wallet,
  });

  @override
  ConsumerState<SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends ConsumerState<SellSheet> {
  final _receive = TextEditingController();
  final _buyer = TextEditingController();
  late final MarketFees _fees = MarketFees(widget.wallet);

  MarketPrice? _price;
  List<double> _history = const [];
  bool _loadingPrice = true;
  bool _busy = false;
  bool _syncing = false;
  late bool _autoConfirm;
  int _quantity = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _autoConfirm =
        ref
            .read(appControllerProvider)
            .value
            ?.store
            .manifest
            .autoConfirmMarketTransactions ??
        false;
    _load();
  }

  @override
  void dispose() {
    _receive.dispose();
    _buyer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final market = ref.read(marketClientProvider);
      final p = await market.priceOverview(
        widget.item.appid,
        widget.item.marketHashName,
        widget.wallet.currency,
      );
      final h = await market.priceHistory(
        widget.account,
        widget.item.appid,
        widget.item.marketHashName,
      );
      if (!mounted) return;
      setState(() {
        _price = p;
        _history = h;
        _loadingPrice = false;
      });
    } catch (_) {
      // Price data is advisory — fall through to "price unavailable" instead
      // of leaving the progress bar stuck.
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  String _fromMinor(int m) => (m / 100).toStringAsFixed(2);

  void _onReceiveChanged(String s) {
    if (_syncing) return;
    _syncing = true;
    final minor = parsePriceToMinor(s) ?? 0;
    _buyer.text = minor > 0
        ? _fromMinor(
            _fees.buyerPays(minor, publisherPct: widget.item.publisherFeePct),
          )
        : '';
    _syncing = false;
  }

  void _onBuyerChanged(String s) {
    if (_syncing) return;
    _syncing = true;
    final minor = parsePriceToMinor(s) ?? 0;
    _receive.text = minor > 0
        ? _fromMinor(
            _fees.receiveFromTotal(
              minor,
              publisherPct: widget.item.publisherFeePct,
            ),
          )
        : '';
    _syncing = false;
  }

  Future<void> _list() async {
    final l = AppLocalizations.of(context);
    final minor = parsePriceToMinor(_receive.text) ?? 0;
    if (minor <= 0) {
      setState(() => _error = l.marketInvalidPrice);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final market = ref.read(marketClientProvider);
      final confirmations = ref.read(confirmationsClientProvider);

      // Snapshot the market-listing confirmations that already exist BEFORE we
      // create ours, so auto-confirm only ever approves the listing(s) made
      // here — never a pending market confirmation the user set up elsewhere.
      // If this fetch fails we can't tell old from new, so we skip auto-confirm
      // entirely (safer than risking approving something unintended).
      Set<String>? preExistingCreatorIds;
      try {
        final pre = await confirmations.fetch(widget.account);
        preExistingCreatorIds = pre
            .where((c) => c.type == ConfirmationType.marketListing)
            .map((c) => c.creatorId)
            .toSet();
      } catch (_) {
        preExistingCreatorIds = null;
      }

      final ids = widget.assetIds.take(_quantity).toList();
      var listed = 0;
      var needsConf = false;
      var authExpired = false;
      var consecFails = 0;
      String? failMsg;
      for (final assetId in ids) {
        // One asset failing must not abandon the rest of the batch — but a
        // stale session fails every remaining asset identically, and three
        // straight hard failures with no success in between mean the batch
        // is doomed (network down, Steam erroring): both break out instead
        // of serially timing out on every remaining asset.
        try {
          final r = await market.sell(
            widget.account,
            widget.item,
            minor,
            assetId: assetId,
          );
          if (r.success) {
            listed++;
            consecFails = 0;
            needsConf = needsConf || r.requiresConfirmation;
          } else {
            failMsg = r.message;
          }
        } on CommunityAuthException {
          // Mid-batch expiry must not discard the partial-success
          // accounting: assets already listed are live and need reporting.
          authExpired = true;
          break;
        } on SteamApiException catch (e) {
          failMsg = e.message.isNotEmpty ? e.message : '$e';
          if (++consecFails >= 3) break;
        }
      }
      if (!mounted) return;
      if (listed == 0) {
        setState(() {
          _busy = false;
          _error = authExpired ? l.sessionExpired : (failMsg ?? l.commonError);
        });
        return;
      }
      // Auto-confirm only the confirmations that appeared for THIS listing.
      // Pointless on a dead session — every mobileconf call would fail too.
      var autoConfirmedOk = false;
      BatchResult? confirmRes;
      if (!authExpired &&
          needsConf &&
          _autoConfirm &&
          preExistingCreatorIds != null) {
        try {
          final latest = await confirmations.fetch(widget.account);
          final newConfs = newMarketConfirmations(
            preExistingCreatorIds,
            latest,
          );
          if (newConfs.isNotEmpty) {
            final res = await confirmations.respondMultiple(
              widget.account,
              newConfs,
              true,
            );
            // "Confirmed" may only be claimed when every confirmation for
            // this listing actually went through — a silent failure here is
            // an unconfirmed listing the user believes is live (lost sale).
            confirmRes = res;
            autoConfirmedOk = autoConfirmSucceeded(res);
          }
        } catch (_) {
          // The listing itself already succeeded; fall through to the
          // "confirm it to finish" snackbar instead of an error state.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      // Truthful reporting: a partial batch or a mid-batch session expiry
      // must never read as a full success.
      final String msg;
      if (authExpired) {
        msg = l.marketListedSessionExpired(listed, ids.length);
      } else if (listed < ids.length) {
        msg = l.marketListedPartial(listed, ids.length);
      } else if (needsConf && !autoConfirmedOk) {
        msg = (confirmRes != null && confirmRes.ok > 0)
            ? l.marketConfirmPartial(
                confirmRes.ok, confirmRes.ok + confirmRes.failed)
            : l.marketListed;
      } else {
        msg = l.marketListedDone;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on CommunityAuthException {
      // The session cookie was already stale before anything listed — point
      // the user at re-auth instead of echoing a raw exception.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.sessionExpired;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.marketListFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final fmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.panel2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius)),
          border: Border.all(color: t.line, width: t.borderWidth),
        ),
        padding: context.rInsets(all: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.item.iconUrl.isNotEmpty)
                  Image.network(
                    widget.item.iconUrl,
                    width: context.r(48),
                    cacheWidth: context.rCache(48),
                  ),
                SizedBox(width: context.r(12)),
                Expanded(
                  child: Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.text,
                      fontSize: context.r(15),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.r(12)),
            if (_loadingPrice)
              const LinearProgressIndicator()
            else ...[
              Row(
                children: [
                  if (_price?.lowest != null)
                    Text(
                      '${l.marketLowest}: ${_price!.lowest}  ',
                      style: TextStyle(color: t.good, fontSize: context.r(13)),
                    ),
                  if (_price?.median != null)
                    Text(
                      '${l.marketMedian}: ${_price!.median}',
                      style: TextStyle(color: t.muted, fontSize: context.r(13)),
                    ),
                  if (_price?.lowest == null && _price?.median == null)
                    Text(
                      l.marketPriceUnavailable,
                      style: TextStyle(color: t.muted, fontSize: context.r(12)),
                    ),
                ],
              ),
              if (_history.length >= 2) ...[
                SizedBox(height: context.r(8)),
                SizedBox(
                  height: context.r(48),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _Sparkline(_history, t.accent, t.line),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _SparkLabel(
                          text:
                              '${l.marketHigh} ${_history.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}',
                          color: t.good,
                          panel: t.panel2,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: _SparkLabel(
                          text:
                              '${l.marketLow} ${_history.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}',
                          color: t.bad,
                          panel: t.panel2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            SizedBox(height: context.r(14)),
            Row(
              children: [
                Expanded(
                  child: _priceField(
                    _receive,
                    l.marketYouReceive,
                    fmt,
                    _onReceiveChanged,
                    t,
                  ),
                ),
                SizedBox(width: context.r(12)),
                Expanded(
                  child: _priceField(
                    _buyer,
                    l.marketBuyerPays,
                    fmt,
                    _onBuyerChanged,
                    t,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.r(4)),
            Text(
              l.marketFeeNote,
              style: TextStyle(color: t.muted, fontSize: context.r(11)),
            ),
            if (widget.assetIds.length > 1)
              Padding(
                padding: context.rInsets(v: 8),
                child: Row(
                  children: [
                    Text(
                      '${l.marketQuantity}  ',
                      style: TextStyle(color: t.text, fontSize: context.r(14)),
                    ),
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_quantity',
                      style: TextStyle(
                        color: t.accent,
                        fontSize: context.r(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _quantity < widget.assetIds.length
                          ? () => setState(() => _quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Text(
                      '/ ${widget.assetIds.length}',
                      style: TextStyle(color: t.muted, fontSize: context.r(13)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _quantity < widget.assetIds.length
                          ? () => setState(
                              () => _quantity = widget.assetIds.length,
                            )
                          : null,
                      child: Text(l.marketMax),
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _autoConfirm,
              onChanged: (v) => setState(() => _autoConfirm = v),
              title: Text(
                l.marketAutoConfirm,
                style: TextStyle(fontSize: context.r(13)),
              ),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: t.bad)),
            SizedBox(height: context.r(12)),
            FilledButton(
              onPressed: _busy ? null : _list,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.marketListButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField(
    TextEditingController c,
    String label,
    List<TextInputFormatter> fmt,
    ValueChanged<String> onChanged,
    AvaTokens t,
  ) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: fmt,
      onChanged: onChanged,
      style: TextStyle(fontSize: context.r(20), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: context.rInsets(h: 12, v: 10),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// High/low tag over the sparkline — a translucent panel backing keeps it
/// readable when it lands on top of the line.
class _SparkLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Color panel;
  const _SparkLabel({
    required this.text,
    required this.color,
    required this.panel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.r(4),
        vertical: context.r(1),
      ),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: context.r(10.5)),
      ),
    );
  }
}

/// A tiny price-trend line.
class _Sparkline extends CustomPainter {
  final List<double> data;
  final Color line;
  final Color grid;
  _Sparkline(this.data, this.line, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    var lo = data.first, hi = data.first;
    for (final v in data) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final range = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    final dx = size.width / (data.length - 1);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = dx * i;
      final y = size.height - ((data[i] - lo) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    // baseline
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.data != data;
}
