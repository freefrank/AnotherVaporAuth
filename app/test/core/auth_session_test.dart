import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/protocol/steam_auth_session.dart';

String _jwt(Map<String, dynamic> payload) {
  String seg(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${seg('{"typ":"JWT","alg":"EdDSA"}')}.${seg(jsonEncode(payload))}.signature';
}

void main() {
  group('steamIdFromJwt', () {
    test('extracts the sub claim (steamid)', () {
      final token = _jwt({
        'iss': 'steam',
        'sub': '76561198000000000',
        'aud': ['mobile'],
      });
      expect(SteamAuthSession.steamIdFromJwt(token), 76561198000000000);
    });

    test('returns null for malformed tokens', () {
      expect(SteamAuthSession.steamIdFromJwt(null), isNull);
      expect(SteamAuthSession.steamIdFromJwt(''), isNull);
      expect(SteamAuthSession.steamIdFromJwt('not.a.jwt.really'), isNull);
      expect(SteamAuthSession.steamIdFromJwt('onlyonepart'), isNull);
    });
  });
}
