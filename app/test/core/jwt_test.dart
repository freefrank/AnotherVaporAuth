import 'dart:convert';

import 'package:ava/src/core/jwt.dart';
import 'package:flutter_test/flutter_test.dart';

/// A structurally valid JWT-ish token: fake header/signature around a real
/// base64url payload with the padding stripped, as Steam's tokens ship.
String _jwt(Object payload) {
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return 'hdr.${body.replaceAll('=', '')}.sig';
}

void main() {
  group('decodeJwtPayload', () {
    test('decodes an unpadded base64url payload', () {
      final payload = {'sub': '76561198000000123', 'exp': 1893456000};
      expect(decodeJwtPayload(_jwt(payload)), payload);
    });

    test('two segments (no signature) still decode', () {
      final token = _jwt({'exp': 1});
      final noSig = token.substring(0, token.lastIndexOf('.'));
      expect(decodeJwtPayload(noSig), {'exp': 1});
    });

    test('null and empty input', () {
      expect(decodeJwtPayload(null), isNull);
      expect(decodeJwtPayload(''), isNull);
    });

    test('too few segments', () {
      expect(decodeJwtPayload('onlyonepart'), isNull);
    });

    test('payload segment is not base64', () {
      expect(decodeJwtPayload('a.!!!.c'), isNull);
    });

    test('payload segment is base64 but not JSON', () {
      final garbage = base64Url.encode(utf8.encode('not json'));
      expect(decodeJwtPayload('a.$garbage.c'), isNull);
    });

    test('payload segment is JSON but not an object', () {
      expect(decodeJwtPayload(_jwt([1, 2, 3])), isNull);
    });
  });
}
