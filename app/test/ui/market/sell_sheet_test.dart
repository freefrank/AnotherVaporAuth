import 'package:ava/src/core/models/confirmation.dart';
import 'package:ava/src/core/protocol/confirmations_client.dart';
import 'package:ava/src/ui/market/sell_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Confirmation _conf(
  String creatorId, {
  ConfirmationType type = ConfirmationType.marketListing,
}) => Confirmation(
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

  group('parsePriceToMinor (audit #6 price parsing fix)', () {
    test('comma is a decimal separator', () {
      expect(parsePriceToMinor('12,50'), 1250);
      expect(parsePriceToMinor('12,5'), 1250);
      expect(parsePriceToMinor('  3,5 '), 350);
    });

    test('dot is a decimal separator', () {
      expect(parsePriceToMinor('12.50'), 1250);
      expect(parsePriceToMinor('12'), 1200);
      // Dart accepts a trailing dot — matters while typing "12," live.
      expect(parsePriceToMinor('12.'), 1200);
      expect(parsePriceToMinor('.5'), 50);
    });

    test(
      'mixed thousands+decimal separators are ambiguous, never a listing',
      () {
        // '1.234,56' normalizes to '1.234.56' — silently listing 123 minor
        // (~1000× under) was the original bug.
        expect(parsePriceToMinor('1.234,56'), isNull);
        expect(parsePriceToMinor('1,234.56'), isNull);
      },
    );

    test('a separator followed by 3+ digits is thousands-looking, never a '
        'listing', () {
      // '1,234' would list at ~1000× under for a user who meant one thousand
      // two hundred thirty-four; prices carry at most two decimals.
      expect(parsePriceToMinor('1,234'), isNull);
      expect(parsePriceToMinor('1.234'), isNull);
      expect(parsePriceToMinor('12.345'), isNull);
    });

    test('a repeated separator is never a listing', () {
      expect(parsePriceToMinor('1,234,567'), isNull);
      expect(parsePriceToMinor('1.234.567'), isNull);
    });

    test('empty and non-positive input yields null', () {
      expect(parsePriceToMinor(''), isNull);
      expect(parsePriceToMinor('.'), isNull);
      expect(parsePriceToMinor('0'), isNull);
    });

    test('the input formatter passes the comma through', () {
      expect(RegExp(r'[0-9.,]').hasMatch(','), isTrue);
    });
  });

  group('autoConfirmSucceeded (audit #15)', () {
    test('whole batch approved', () {
      expect(autoConfirmSucceeded(const BatchResult(2, 0)), isTrue);
    });

    test('total failure', () {
      expect(autoConfirmSucceeded(const BatchResult(0, 2)), isFalse);
    });

    test('partial success still needs a manual confirm', () {
      expect(autoConfirmSucceeded(const BatchResult(1, 1)), isFalse);
    });

    test('empty batch claims nothing', () {
      expect(autoConfirmSucceeded(const BatchResult(0, 0)), isFalse);
    });
  });
}
