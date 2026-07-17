import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/confirmations_client.dart';
import 'package:ava/src/core/steam_totp.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake community API that records the last getlist query and replays a
/// canned JSON response.
class _FakeApi extends SteamApiClient {
  final Map<String, dynamic> response;
  final Object? error;
  Map<String, dynamic>? lastQuery;
  _FakeApi(this.response, {this.error});

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    lastQuery = query;
    if (error != null) throw error!;
    return response;
  }
}

SteamGuardAccount _account({String? deviceId}) => SteamGuardAccount(
      identitySecret: 'YQ==',
      deviceId: deviceId,
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: 'tok',
        refreshToken: 'r',
      ),
    );

void main() {
  group('ConfirmationsClient.fetch — success=false handling', () {
    test('a signature-level rejection throws, not an empty list', () async {
      // Steam answers getlist with success=false + a localized "Oh no!"
      // message when the identity_secret/device_id doesn't match the
      // account's registered authenticator. Returning [] here made the UI
      // show "no pending confirmations" for a hard rejection.
      final api = _FakeApi({'success': false, 'message': '哦，不！'});
      await expectLater(
        ConfirmationsClient(api).fetch(_account(deviceId: 'android:x')),
        throwsA(isA<ConfirmationRejectedException>()
            .having((e) => e.message, 'message', '哦，不！')),
      );
    });

    test('needauth still maps to ConfirmationAuthException', () async {
      final api = _FakeApi({'success': false, 'needauth': true});
      await expectLater(
        ConfirmationsClient(api).fetch(_account(deviceId: 'android:x')),
        throwsA(isA<ConfirmationAuthException>()),
      );
    });

    test('an HTTP-level CommunityAuthException maps to ConfirmationAuth',
        () async {
      // A stale session now surfaces as a 302/401 throw from the API layer
      // instead of a success-shaped {}; fetch must route it to the same
      // re-auth path as needauth, not the wrong-secret rejection message.
      final api = _FakeApi(const {},
          error: const CommunityAuthException(302, '/mobileconf/getlist'));
      await expectLater(
        ConfirmationsClient(api).fetch(_account(deviceId: 'android:x')),
        throwsA(isA<ConfirmationAuthException>()),
      );
    });

    test('success with no conf array is a plain empty list', () async {
      final api = _FakeApi({'success': true});
      expect(await ConfirmationsClient(api).fetch(_account(deviceId: 'android:x')),
          isEmpty);
    });
  });

  group('device_id fallback', () {
    test('a missing device_id is synthesized, never sent empty', () async {
      final api = _FakeApi({'success': true, 'conf': []});
      await ConfirmationsClient(api).fetch(_account());
      final p = api.lastQuery!['p'] as String;
      expect(p, isNotEmpty);
      expect(p, SteamTotp.generateDeviceId(76561198000000123));
    });

    test('an explicit device_id is passed through untouched', () async {
      final api = _FakeApi({'success': true, 'conf': []});
      await ConfirmationsClient(api).fetch(_account(deviceId: 'android:abc'));
      expect(api.lastQuery!['p'], 'android:abc');
    });
  });

  group('SteamTotp.generateDeviceId', () {
    test('is deterministic and android-uuid shaped', () {
      final a = SteamTotp.generateDeviceId(76561198000000123);
      final b = SteamTotp.generateDeviceId(76561198000000123);
      expect(a, b);
      expect(
          a,
          matches(RegExp(
              r'^android:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      expect(SteamTotp.generateDeviceId(1), isNot(a));
    });
  });
}
