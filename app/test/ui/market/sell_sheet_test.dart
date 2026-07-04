import 'package:ava/src/core/models/confirmation.dart';
import 'package:ava/src/ui/market/sell_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Confirmation _conf(String creatorId,
        {ConfirmationType type = ConfirmationType.marketListing}) =>
    Confirmation(
      id: 'id-$creatorId',
      nonce: 'nonce-$creatorId',
      type: type,
      typeName: 'type',
      creatorId: creatorId,
      headline: 'headline',
      summary: const [],
      creationTime: 0,
      icon: '',
    );

void main() {
  group('newMarketConfirmations (audit #7 auto-confirm fix)', () {
    test('excludes confirmations that were already pending', () {
      final preExisting = {'100'};
      final latest = [_conf('100'), _conf('200')];

      final result = newMarketConfirmations(preExisting, latest);

      expect(result.map((c) => c.creatorId), ['200']);
    });

    test('includes only newly-appeared confirmations', () {
      final preExisting = <String>{};
      final latest = [_conf('1'), _conf('2'), _conf('3')];

      final result = newMarketConfirmations(preExisting, latest);

      expect(result.map((c) => c.creatorId).toSet(), {'1', '2', '3'});
    });

    test('empty preExisting and empty latest is safe', () {
      final result = newMarketConfirmations(<String>{}, const []);
      expect(result, isEmpty);
    });

    test('all latest already pending yields empty result', () {
      final preExisting = {'1', '2'};
      final latest = [_conf('1'), _conf('2')];

      final result = newMarketConfirmations(preExisting, latest);

      expect(result, isEmpty);
    });

    test('non-marketListing confirmations are never included', () {
      final preExisting = <String>{};
      final latest = [
        _conf('1', type: ConfirmationType.trade),
        _conf('2', type: ConfirmationType.other),
        _conf('3'),
      ];

      final result = newMarketConfirmations(preExisting, latest);

      expect(result.map((c) => c.creatorId), ['3']);
    });
  });
}
