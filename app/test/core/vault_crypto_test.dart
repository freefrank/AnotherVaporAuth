import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Low KDF rounds keep the tests fast; production uses the default.
  const rounds = 200;

  group('VaultCrypto DEK generation', () {
    test('generateDek returns 32 random bytes, not all zero', () {
      final a = VaultCrypto.generateDek();
      final b = VaultCrypto.generateDek();
      expect(a.length, 32);
      expect(a.any((x) => x != 0), isTrue);
      expect(a, isNot(equals(b)));
    });

    test('randomSaltB64 decodes to 16 bytes and varies', () {
      final s1 = base64.decode(VaultCrypto.randomSaltB64());
      final s2 = base64.decode(VaultCrypto.randomSaltB64());
      expect(s1.length, 16);
      expect(s1, isNot(equals(s2)));
    });
  });

  group('DEK wrap / unwrap (PIN-bound)', () {
    test('opens a wrap produced by the original pointycastle implementation',
        () {
      // Fixture generated with the pre-hashlib code (pointycastle PBKDF2 +
      // GCM) — locks byte-compatibility so existing users' wraps keep
      // opening across KDF implementation changes.
      const salt = 'BxQhLjtIVWJvfImWo7C9yg==';
      const blob =
          'AQYLEBUaHyQpLjM4L3Y7YjQysD/gz3dYxSkkPNohyMrR5PKPDsPfbq9EB8kuiqjkB50Lwdp14IFk4I9y';
      const dekB64 = 'Aw4ZJC86RVBbZnF8h5KdqLO+ydTf6vUACxYhLDdCTVg=';
      final out =
          VaultCrypto.unwrapDek('123456', salt, blob, iterations: 1000);
      expect(out, isNotNull);
      expect(base64.encode(out!), dekB64);
    });

    test('round trips with the correct PIN', () {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.randomSaltB64();
      final blob = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      final out = VaultCrypto.unwrapDek('123456', salt, blob, iterations: rounds);
      expect(out, equals(dek));
    });

    test('wrong PIN returns null (GCM tag fails)', () {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.randomSaltB64();
      final blob = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      expect(VaultCrypto.unwrapDek('654321', salt, blob, iterations: rounds),
          isNull);
    });

    test('tampered blob returns null', () {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.randomSaltB64();
      final blob = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      final bytes = base64.decode(blob);
      bytes[bytes.length - 1] ^= 0xFF; // flip a tag byte
      final tampered = base64.encode(bytes);
      expect(VaultCrypto.unwrapDek('123456', salt, tampered, iterations: rounds),
          isNull);
    });

    test('wrong salt returns null', () {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.randomSaltB64();
      final blob = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      final otherSalt = VaultCrypto.randomSaltB64();
      expect(
          VaultCrypto.unwrapDek('123456', otherSalt, blob, iterations: rounds),
          isNull);
    });

    test('each wrap uses a fresh nonce (blobs differ)', () {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.randomSaltB64();
      final b1 = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      final b2 = VaultCrypto.wrapDek('123456', salt, dek, iterations: rounds);
      expect(b1, isNot(equals(b2)));
    });
  });

  group('payload encrypt / decrypt (DEK)', () {
    test('round trips unicode plaintext', () {
      final dek = VaultCrypto.generateDek();
      const plain = '{"account_name":"cider","persona":"测试 🎮"}';
      final blob = VaultCrypto.encryptPayload(dek, plain);
      expect(VaultCrypto.decryptPayload(dek, blob), plain);
    });

    test('wrong DEK returns null', () {
      final dek = VaultCrypto.generateDek();
      final blob = VaultCrypto.encryptPayload(dek, 'hello');
      expect(VaultCrypto.decryptPayload(VaultCrypto.generateDek(), blob),
          isNull);
    });

    test('tampered ciphertext returns null', () {
      final dek = VaultCrypto.generateDek();
      final blob = VaultCrypto.encryptPayload(dek, 'hello world payload');
      final bytes = base64.decode(blob);
      bytes[bytes.length ~/ 2] ^= 0x01;
      expect(VaultCrypto.decryptPayload(dek, base64.encode(bytes)), isNull);
    });

    test('two encryptions of the same text differ (fresh nonce)', () {
      final dek = VaultCrypto.generateDek();
      final a = VaultCrypto.encryptPayload(dek, 'same');
      final b = VaultCrypto.encryptPayload(dek, 'same');
      expect(a, isNot(equals(b)));
    });

    test('blob layout is nonce(12) + ciphertext + tag(16)', () {
      final dek = VaultCrypto.generateDek();
      final blob = VaultCrypto.encryptPayload(dek, 'x');
      final raw = base64.decode(blob);
      // 12 nonce + 1 plaintext byte + 16 tag = 29
      expect(raw.length, 12 + 1 + 16);
    });
  });

  test('wrapDek accepts a Uint8List DEK of any typed-data view', () {
    final dek = Uint8List.fromList(List.generate(32, (i) => i));
    final salt = VaultCrypto.randomSaltB64();
    final blob = VaultCrypto.wrapDek('000000', salt, dek, iterations: rounds);
    expect(VaultCrypto.unwrapDek('000000', salt, blob, iterations: rounds),
        equals(dek));
  });
}
