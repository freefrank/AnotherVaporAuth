import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/steam_totp.dart';

void main() {
  // Reference values produced by an independent Python implementation of the
  // Steam TOTP / confirmation algorithms (cross-implementation check).
  const sharedSecret = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA='; // b'12345678901234567890'
  const identitySecret = 'YWJjZGVmZ2hpamtsbW5vcHFyc3Q='; // b'abcdefghijklmnopqrst'

  group('Steam Guard auth code', () {
    test('matches reference vector @1700000000', () {
      expect(SteamTotp.generateAuthCode(sharedSecret, 1700000000), 'R87JJ');
    });

    test('matches reference vector @1634000000', () {
      expect(SteamTotp.generateAuthCode(sharedSecret, 1634000000), 'D6C35');
    });

    test('code is 5 chars from the Steam alphabet', () {
      final code = SteamTotp.generateAuthCode(sharedSecret, 1699999999);
      expect(code.length, 5);
      expect(RegExp(r'^[23456789BCDFGHJKMNPQRTVWXY]{5}$').hasMatch(code), isTrue);
    });

    test('code is stable within a 30s window', () {
      // Window boundaries are multiples of 30: [1699999980, 1700000010).
      final a = SteamTotp.generateAuthCode(sharedSecret, 1700000000);
      final b = SteamTotp.generateAuthCode(sharedSecret, 1700000009);
      expect(a, b);
    });

    test('code changes across window boundary', () {
      final a = SteamTotp.generateAuthCode(sharedSecret, 1700000009);
      final b = SteamTotp.generateAuthCode(sharedSecret, 1700000010);
      expect(a, isNot(b));
    });
  });

  group('Confirmation hash', () {
    test('matches reference vector tag=conf', () {
      expect(
        SteamTotp.generateConfirmationHash(1700000000, 'conf', identitySecret),
        'lARGXtefNbogvcyP7DZJI0+XBYQ=',
      );
    });

    test('matches reference vector tag=allow', () {
      expect(
        SteamTotp.generateConfirmationHash(1700000000, 'allow', identitySecret),
        'v53H1MfBVFOCKLLTFJpiE7RCHWY=',
      );
    });
  });

  group('secondsRemaining', () {
    test('counts down within window', () {
      expect(SteamTotp.secondsRemaining(1700000010), 30); // multiple of 30
      expect(SteamTotp.secondsRemaining(1700000011), 29);
      expect(SteamTotp.secondsRemaining(1700000039), 1);
    });
  });
}
