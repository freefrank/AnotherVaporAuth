import 'package:ava/src/core/market_fees.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Constants read live from g_rgWalletInfo for a CNY wallet:
  // steam 5%, publisher 10%, market_minimum 7, increment 1.
  const cny = WalletInfo(
    currency: 23,
    steamFeePct: 0.05,
    publisherFeePct: 0.10,
    marketMinimum: 7,
    currencyIncrement: 1,
  );
  const fees = MarketFees(cny);

  group('buyerPays matches Steam ground truth (CNY 5%/10%, min 7)', () {
    // {youReceive: buyerPays} captured live from Steam's GetTotalWithFees.
    const samples = {
      1: 21,
      7: 21,
      10: 24,
      50: 64,
      100: 117,
      233: 267,
      999: 1147,
      1000: 1150,
      12345: 14196,
    };
    samples.forEach((receive, expected) {
      test('receive $receive -> buyer pays $expected', () {
        expect(fees.buyerPays(receive), expected);
      });
    });
  });

  test('breakdown splits steam + publisher fees correctly', () {
    final b = fees.breakdown(100);
    expect(b.steamFee, 7); // max(floor(100*0.05)=5, 7) = 7
    expect(b.publisherFee, 10); // floor(100*0.10) = 10
    expect(b.buyerPays, 117);
    expect(b.totalFee, 17);
  });

  test('receiveFromTotal is the inverse of buyerPays', () {
    for (final receive in [7, 10, 50, 100, 233, 999, 1000, 12345]) {
      final total = fees.buyerPays(receive);
      expect(fees.receiveFromTotal(total), receive,
          reason: 'total $total should map back to receive $receive');
    }
  });

  test('USD-like wallet (min 1) uses the standard minimums', () {
    const usd = MarketFees(WalletInfo.fallback);
    // receive 100c: steam max(5,1)=5, publisher max(10,1)=10 -> buyer 115
    expect(usd.buyerPays(100), 115);
  });
}
