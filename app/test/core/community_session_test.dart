import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount _account({String? token}) => SteamGuardAccount(
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: token,
        refreshToken: 'r',
      ),
    );

void main() {
  group('requireAccessToken', () {
    test('returns the token when present', () {
      expect(requireAccessToken(_account(token: 'tok')), 'tok');
    });

    test('throws on a missing token', () {
      expect(() => requireAccessToken(_account()),
          throwsA(isA<MissingAccessTokenException>()));
    });

    test('throws on an empty token (refresh-only session)', () {
      expect(() => requireAccessToken(_account(token: '')),
          throwsA(isA<MissingAccessTokenException>()));
    });
  });

  group('newCommunitySessionId', () {
    test('is 24 lowercase hex chars and not constant', () {
      final a = newCommunitySessionId();
      final b = newCommunitySessionId();
      expect(a, matches(RegExp(r'^[0-9a-f]{24}$')));
      expect(b, matches(RegExp(r'^[0-9a-f]{24}$')));
      expect(a, isNot(b));
    });
  });

  group('communityCookies', () {
    test('default shape: steamLoginSecure + given sessionid + mobileClient',
        () {
      final cookies = communityCookies(_account(token: 'tok'), sessionId: 'sid');
      expect(cookies, {
        'steamLoginSecure': '76561198000000123||tok',
        'sessionid': 'sid',
        'mobileClient': 'android',
      });
    });

    test('mints a fresh sessionid when none is given', () {
      final cookies = communityCookies(_account(token: 'tok'));
      expect(cookies['sessionid'], matches(RegExp(r'^[0-9a-f]{24}$')));
    });

    test('missing access token degrades to an empty token, not a crash', () {
      final cookies = communityCookies(_account(), sessionId: 'sid');
      expect(cookies['steamLoginSecure'], '76561198000000123||');
    });

    test('confirmationVariant: mobileClientVersion instead of sessionid', () {
      final cookies =
          communityCookies(_account(token: 'tok'), confirmationVariant: true);
      expect(cookies, {
        'steamLoginSecure': '76561198000000123||tok',
        'mobileClient': 'android',
        'mobileClientVersion': '777777 3.6.4',
      });
    });
  });
}
