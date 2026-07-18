import 'package:ava/src/core/crypto/secure_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secureRandomBytes', () {
    test('returns exactly n bytes', () {
      expect(secureRandomBytes(0), isEmpty);
      expect(secureRandomBytes(1).length, 1);
      expect(secureRandomBytes(32).length, 32);
    });

    test('two draws differ (collision odds 2^-256)', () {
      expect(secureRandomBytes(32), isNot(secureRandomBytes(32)));
    });

    test('a long draw is not a constant byte', () {
      final bytes = secureRandomBytes(256);
      expect(bytes.toSet().length, greaterThan(1));
    });
  });

  group('secureRandomHex', () {
    test('length and charset', () {
      final hex = secureRandomHex(24);
      expect(hex, matches(RegExp(r'^[0-9a-f]{24}$')));
      expect(secureRandomHex(0), isEmpty);
    });

    test('two draws differ', () {
      expect(secureRandomHex(24), isNot(secureRandomHex(24)));
    });
  });
}
