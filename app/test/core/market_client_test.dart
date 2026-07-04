import 'package:ava/src/core/protocol/market_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketClient.isCancelSuccess', () {
    test('bare/empty body (Steam\'s normal removelisting reply) is success',
        () {
      expect(MarketClient.isCancelSuccess(const {}), isTrue);
    });

    test('explicit success:true is success', () {
      expect(MarketClient.isCancelSuccess(const {'success': true}), isTrue);
    });

    test('explicit success:false is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'success': false}), isFalse);
    });

    test('success:false with a message is still a failure', () {
      expect(
        MarketClient.isCancelSuccess(
            const {'success': false, 'message': 'You already sold this'}),
        isFalse,
      );
    });

    test('needauth marker is a failure even without success:false', () {
      expect(MarketClient.isCancelSuccess(const {'needauth': true}), isFalse);
    });

    test('needsauth (alternate key) marker is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'needsauth': true}), isFalse);
    });

    test('needauth wins even if success is truthy', () {
      expect(
        MarketClient.isCancelSuccess(const {'success': true, 'needauth': true}),
        isFalse,
      );
    });

    test('a non-boolean success value does not count as success', () {
      expect(MarketClient.isCancelSuccess(const {'success': 1}), isFalse);
    });
  });
}
