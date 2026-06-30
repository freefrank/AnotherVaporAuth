import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/crypto/ma_file_crypto.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA1 (byte-compat lock)', () {
    test('RFC 6070 vector: password/salt, c=4096, dkLen=20', () {
      // base64("salt") == "c2FsdA=="
      final key = MaFileCrypto.deriveKey(
        'password',
        base64.encode(utf8.encode('salt')),
        iterations: 4096,
        dkLen: 20,
      );
      expect(_hex(key), '4b007901b765489abead49d926f721d065a429c1');
    });

    test('RFC 6070 vector: c=1, dkLen=20', () {
      final key = MaFileCrypto.deriveKey(
        'password',
        base64.encode(utf8.encode('salt')),
        iterations: 1,
        dkLen: 20,
      );
      expect(_hex(key), '0c60c80f961f0e71f3a9b524af6012062fe037a6');
    });
  });

  group('AES-256-CBC + PKCS7 round trip', () {
    test('encrypt then decrypt yields original', () {
      const password = 'hunter2';
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      const plain = '{"shared_secret":"abc","account_name":"tester"}';

      final cipher = MaFileCrypto.encrypt(password, salt, iv, plain);
      expect(cipher, isNot(equals(plain)));

      final back = MaFileCrypto.decrypt(password, salt, iv, cipher);
      expect(back, plain);
    });

    test('wrong password returns null (not throw)', () {
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      final cipher = MaFileCrypto.encrypt('right', salt, iv, 'secret data');

      final back = MaFileCrypto.decrypt('wrong', salt, iv, cipher);
      expect(back, isNull);
    });

    test('salt is 8 bytes and iv is 16 bytes', () {
      expect(base64.decode(MaFileCrypto.getRandomSalt()).length, 8);
      expect(base64.decode(MaFileCrypto.getInitializationVector()).length, 16);
    });

    test('unicode plaintext round trips', () {
      final salt = MaFileCrypto.getRandomSalt();
      final iv = MaFileCrypto.getInitializationVector();
      const plain = '账户：测试 — émoji 🎮';
      final cipher = MaFileCrypto.encrypt('пароль', salt, iv, plain);
      expect(MaFileCrypto.decrypt('пароль', salt, iv, cipher), plain);
    });
  });
}
