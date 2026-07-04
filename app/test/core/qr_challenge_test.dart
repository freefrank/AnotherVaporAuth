import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart';

void main() {
  group('QrChallenge.tryParse', () {
    test('parses s.team/q/<version>/<client_id>', () {
      final c = QrChallenge.tryParse('https://s.team/q/1/123456789');
      expect(c, isNotNull);
      expect(c!.version, 1);
      expect(c.clientId, 123456789);
    });

    test('parses steamcommunity host variant', () {
      final c = QrChallenge.tryParse(
          'https://steamcommunity.com/q/2/987654321?foo=bar');
      expect(c!.version, 2);
      expect(c.clientId, 987654321);
    });

    test('parses www.steamcommunity.com variant', () {
      final c = QrChallenge.tryParse('https://www.steamcommunity.com/q/3/42');
      expect(c!.version, 3);
      expect(c.clientId, 42);
    });

    test('returns null for unrelated text', () {
      expect(QrChallenge.tryParse('not a url'), isNull);
      expect(QrChallenge.tryParse('https://example.com/foo/bar'), isNull);
    });

    test('rejects a valid path shape on a non-Steam host', () {
      expect(QrChallenge.tryParse('https://evil.example/q/1/123'), isNull);
    });

    test('rejects a non-HTTPS scheme on a Steam host', () {
      expect(QrChallenge.tryParse('http://s.team/q/1/123'), isNull);
    });

    test('rejects malformed/short paths on a trusted host', () {
      expect(QrChallenge.tryParse('https://s.team/q/1'), isNull);
      expect(QrChallenge.tryParse('https://s.team/q'), isNull);
      expect(QrChallenge.tryParse('https://s.team/'), isNull);
      expect(QrChallenge.tryParse('https://s.team/q/abc/123'), isNull);
    });
  });
}
