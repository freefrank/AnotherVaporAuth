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

    test('masks padded standard-base64 secrets containing "/"', () {
      // 20-byte Steam secrets are 28 base64 chars always ending '='; a '/'
      // used to split the bare no-slash pass into unmatched short fragments.
      const secret = 'mBqamz/OY7dfN1zzAAAAExamp0c=';
      final out = DebugLog.redactSecrets('R code: $secret');
      // Assert on a fragment: whole-string containment would pass even with
      // the old partial splitting.
      expect(out, isNot(contains('OY7dfN1zz')));
      expect(out, isNot(contains('mBqamz')));
      expect(out, contains('<redacted:28>'));
    });

    test('padded pass does not eat identifiers or URLs', () {
      const ident = 'input_protobuf_encoded=abc';
      expect(DebugLog.redactSecrets(ident), ident);
      const redirect = '  ↪ redirect https://steamcommunity.com/login/home/'
          '?goto=%2Fmobileconf%2Fgetlist';
      expect(DebugLog.redactSecrets(redirect), redirect);
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
