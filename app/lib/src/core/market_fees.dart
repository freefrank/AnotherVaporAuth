import 'models/steam_item.dart';

/// Steam Community Market fee math — a faithful port of Steam's own
/// `GetTotalWithFees` / `GetItemPriceFromTotal` / `CalculateFee` /
/// `ToValidMarketPrice` (economy_v2.js), verified live against 9 ground-truth
/// samples. All amounts are in the wallet's minor units (e.g. cents).
///
/// The seller enters what they want to **receive**; Steam adds a Steam fee and a
/// publisher (game) fee that the **buyer** pays on top. The `sellitem` request
/// sends the seller-receive amount as `price`.
class MarketFees {
  final WalletInfo wallet;
  const MarketFees(this.wallet);

  double get _steamPct => wallet.steamFeePct;
  double get _pubPct => wallet.publisherFeePct;

  /// Clamp/round a price to a valid market value.
  int toValidMarketPrice(int price) {
    final floor = wallet.marketMinimum;
    final inc = wallet.currencyIncrement;
    if (price <= floor) return floor;
    if (price <= inc) return inc;
    if (inc > 1) return ((price / inc).round()) * inc;
    return price;
  }

  int _fee(int baseAmount, double pct) =>
      pct > 0 ? toValidMarketPrice((baseAmount * pct).floor()) : 0;

  /// Total the buyer pays, given the seller receives [receive]. [publisherPct]
  /// overrides the wallet default for games with a non-standard fee.
  int buyerPays(int receive, {double? publisherPct}) {
    final pub = publisherPct ?? _pubPct;
    return toValidMarketPrice(receive) +
        _fee(receive, pub) +
        _fee(receive, _steamPct);
  }

  /// Inverse: what the seller receives if the buyer pays [total]. Mirrors
  /// Steam's iterative `GetItemPriceFromTotal`.
  int receiveFromTotal(int total, {double? publisherPct}) {
    final pub = publisherPct ?? _pubPct;
    final inc = wallet.currencyIncrement;
    final floor = wallet.marketMinimum;
    final initialGuess = (total / (1.0 + pub + _steamPct)).floor();
    final maxBase = total - (2 * floor);
    var base = toValidMarketPrice(initialGuess < maxBase ? initialGuess : maxBase);
    for (var i = 0; i < 3; i++) {
      final calc = _totalWith(base, pub);
      if (calc == total) return base;
      if (calc < total) {
        base += inc;
      } else {
        base -= inc;
        break;
      }
    }
    return base < floor ? floor : base;
  }

  int _totalWith(int receive, double pub) =>
      toValidMarketPrice(receive) + _fee(receive, pub) + _fee(receive, _steamPct);

  /// Fee breakdown for a given seller-receive amount.
  FeeBreakdown breakdown(int receive, {double? publisherPct}) {
    final pub = publisherPct ?? _pubPct;
    final steamFee = _fee(receive, _steamPct);
    final pubFee = _fee(receive, pub);
    return FeeBreakdown(
      receive: receive,
      steamFee: steamFee,
      publisherFee: pubFee,
      buyerPays: toValidMarketPrice(receive) + steamFee + pubFee,
    );
  }
}

class FeeBreakdown {
  final int receive;
  final int steamFee;
  final int publisherFee;
  final int buyerPays;
  const FeeBreakdown({
    required this.receive,
    required this.steamFee,
    required this.publisherFee,
    required this.buyerPays,
  });

  int get totalFee => steamFee + publisherFee;
}
