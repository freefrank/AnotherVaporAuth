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

    test('returns null for unrelated text', () {
      expect(QrChallenge.tryParse('not a url'), isNull);
      expect(QrChallenge.tryParse('https://example.com/foo/bar'), isNull);
    });
  });
}
