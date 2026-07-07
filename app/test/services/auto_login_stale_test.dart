import 'dart:convert';

import 'package:ava/src/services/auto_login.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> payload) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'EdDSA'})}.${b64(payload)}.sig';
}

void main() {
  group('AutoLogin.accessTokenStale', () {
    test('null / empty / garbage tokens are stale', () {
      expect(AutoLogin.accessTokenStale(null), isTrue);
      expect(AutoLogin.accessTokenStale(''), isTrue);
      expect(AutoLogin.accessTokenStale('not-a-jwt'), isTrue);
      expect(AutoLogin.accessTokenStale('a.!!!.c'), isTrue);
    });

    test('an expired JWT is stale', () {
      final past =
          DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      expect(AutoLogin.accessTokenStale(_jwt({'exp': past})), isTrue);
    });

    test('a JWT expiring inside the skew window counts as stale', () {
      final soon =
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
              1000;
      expect(AutoLogin.accessTokenStale(_jwt({'exp': soon})), isTrue);
    });

    test('a JWT with plenty of lifetime left is fresh', () {
      final later =
          DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch ~/
              1000;
      expect(AutoLogin.accessTokenStale(_jwt({'exp': later})), isFalse);
    });

    test('a JWT without exp is treated as stale (fail closed)', () {
      expect(AutoLogin.accessTokenStale(_jwt({'sub': 'x'})), isTrue);
    });
  });
}
