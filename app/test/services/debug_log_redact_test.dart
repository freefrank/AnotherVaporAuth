import 'package:ava/src/services/debug_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugLog.redactSecrets', () {
    test('masks values of sensitive keys in several syntaxes', () {
      final cases = {
        'access_token=abc123SECRETvalue0000': 'access_token',
        'refresh_token: xyzTOKEN9999secret': 'refresh_token',
        'Cookie: steamLoginSecure=DEADBEEFcookievalue': 'steamLoginSecure',
        '{"shared_secret":"AAAABBBBCCCCsecret"}': 'shared_secret',
        'password=hunter2hunter2': 'password',
      };
      cases.forEach((input, key) {
        final out = DebugLog.redactSecrets(input);
        expect(out, contains('<redacted'), reason: input);
        expect(out, contains(key), reason: 'key label kept: $input');
      });
    });

    test('redacts the actual secret material (no leak)', () {
      const secret = 'abc123SECRETvalue0000';
      expect(DebugLog.redactSecrets('access_token=$secret'),
          isNot(contains(secret)));
    });

    test('masks bare long token-shaped blobs', () {
      const blob = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9AAAA';
      expect(DebugLog.redactSecrets('bearer $blob'), isNot(contains(blob)));
    });

    test('leaves ordinary log lines readable', () {
      const line = '→ GET IAuthenticationService/GetPasswordRSAPublicKey';
      expect(DebugLog.redactSecrets(line), line);
      // Steam IDs are 17 digits — below the blob threshold, kept intact.
      expect(DebugLog.redactSecrets('unlock: 76561198000000000 ok'),
          contains('76561198000000000'));
    });
  });
}
