import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Community POST that always throws the stale-session exception the status
/// gate raises for a 302/401 reply.
class _AuthThrowingApi extends SteamApiClient {
  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    throw CommunityAuthException(302, path);
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
      identitySecret: 'YQ==',
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: 'tok',
        refreshToken: 'r',
      ),
    );

void main() {
  group('MarketClient.isCancelSuccess', () {
    test('bare/empty body (Steam\'s normal removelisting reply) is success',
        () {
      expect(MarketClient.isCancelSuccess(const {}), isTrue);
    });

    test('explicit success:true is success', () {
      expect(MarketClient.isCancelSuccess(const {'success': true}), isTrue);
    });

    test('explicit success:false is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'success': false}), isFalse);
    });

    test('success:false with a message is still a failure', () {
      expect(
        MarketClient.isCancelSuccess(
            const {'success': false, 'message': 'You already sold this'}),
        isFalse,
      );
    });

    test('needauth marker is a failure even without success:false', () {
      expect(MarketClient.isCancelSuccess(const {'needauth': true}), isFalse);
    });

    test('needsauth (alternate key) marker is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'needsauth': true}), isFalse);
    });

    test('needauth wins even if success is truthy', () {
      expect(
        MarketClient.isCancelSuccess(const {'success': true, 'needauth': true}),
        isFalse,
      );
    });

    test('a non-boolean success value does not count as success', () {
      expect(MarketClient.isCancelSuccess(const {'success': 1}), isFalse);
    });
  });

  group('MarketClient.cancel', () {
    test('a stale-session throw yields false, never a fake success', () async {
      // Before the status gate a 302/401 empty body decoded to {} and
      // isCancelSuccess({}) reported "Listing cancelled." while nothing
      // happened; the throw must land in cancel's catch-all as false.
      final client = MarketClient(_AuthThrowingApi());
      expect(await client.cancel(_account(), '123456789'), isFalse);
    });
  });
}
