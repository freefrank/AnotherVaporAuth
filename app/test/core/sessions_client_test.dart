import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart'
    show MissingAccessTokenException;
import 'package:ava/src/core/protocol/sessions_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
  String? lastMethod;
  ProtoWriter? lastRequest;
  String? lastAccessToken;
  bool? lastUseGet;
  _FakeApi(this.responses);

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    lastMethod = '$iface/$method';
    lastRequest = request;
    lastAccessToken = accessToken;
    lastUseGet = useGet;
    return responses.removeAt(0);
  }
}

SteamGuardAccount _account({String? token = 'tok'}) => SteamGuardAccount(
      accountName: 'acc',
      session: SessionData(
          steamId: 76561198000000123, accessToken: token, refreshToken: 'r'),
    );

/// One RefreshTokenDescription, as a nested message writer.
ProtoWriter _device({
  required int tokenId,
  required String desc,
  required int timeUpdated,
  required int platform,
  required bool loggedIn,
  ProtoWriter? lastSeen,
}) {
  final w = ProtoWriter()
    ..writeFixed64(1, tokenId)
    ..writeString(2, desc)
    ..writeVarint(3, timeUpdated)
    ..writeVarint(4, platform)
    ..writeBool(5, loggedIn);
  if (lastSeen != null) w.writeMessage(10, lastSeen);
  return w;
}

ProtoWriter _usage({required int time, String country = '', String city = ''}) =>
    ProtoWriter()
      ..writeVarint(1, time)
      ..writeString(4, country)
      ..writeString(6, city);

/// EnumerateTokens response: two devices + requesting_token = the first one.
/// The first device's token_id has its top bit set (passed as -1) to exercise
/// unsigned fixed64 decoding.
ProtoReader _enumResp() {
  final d1 = _device(
    tokenId: -1, // 0xFFFF...FF → unsigned max
    desc: 'Firefox on Windows',
    timeUpdated: 1752100000,
    platform: 2, // WebBrowser
    loggedIn: true,
    lastSeen: _usage(time: 1752100000, country: 'CN', city: 'Shanghai'),
  );
  final d2 = _device(
    tokenId: 12345,
    desc: 'Steam Deck',
    timeUpdated: 1752200000, // newer → sorts first
    platform: 1, // SteamClient
    loggedIn: true,
  );
  final w = ProtoWriter()
    ..writeMessage(1, d1)
    ..writeMessage(1, d2)
    ..writeFixed64(2, -1); // requesting_token = d1
  return ProtoReader(w.toBytes());
}

void main() {
  group('enumerate', () {
    test('uses POST (not GET) with the access token', () async {
      final api = _FakeApi([_enumResp()]);
      await SessionsClient(api).enumerate(_account());
      expect(api.lastMethod, 'IAuthenticationService/EnumerateTokens');
      // EnumerateTokens is NOT a bConstMethod → must be POST, unlike the
      // neighbouring GetAuthSessionsForAccount. Guards the GET/POST trap.
      expect(api.lastUseGet, isFalse);
      expect(api.lastAccessToken, 'tok');
    });

    test('parses devices, sorts newest first, flags current', () async {
      final api = _FakeApi([_enumResp()]);
      final list = await SessionsClient(api).enumerate(_account());
      expect(list.devices, hasLength(2));
      // Sorted by time_updated desc.
      expect(list.devices[0].description, 'Steam Deck');
      expect(list.devices[1].description, 'Firefox on Windows');
      expect(list.devices[0].platformType, 1);
      // requesting_token == d1's token_id → d1 is the current device.
      expect(list.isCurrent(list.devices[1]), isTrue);
      expect(list.isCurrent(list.devices[0]), isFalse);
    });

    test('decodes token_id as unsigned fixed64 (top bit set)', () async {
      final api = _FakeApi([_enumResp()]);
      final list = await SessionsClient(api).enumerate(_account());
      final firefox = list.devices.firstWhere((d) => d.platformType == 2);
      // -1 as fixed64 → 0xFFFFFFFFFFFFFFFF, not a negative int.
      expect(firefox.tokenId, '18446744073709551615');
      expect(list.requestingTokenId, '18446744073709551615');
    });

    test('parses nested last_seen location', () async {
      final api = _FakeApi([_enumResp()]);
      final list = await SessionsClient(api).enumerate(_account());
      final firefox = list.devices.firstWhere((d) => d.platformType == 2);
      expect(firefox.lastSeen, isNotNull);
      expect(firefox.lastSeen!.locationLabel, 'Shanghai, CN');
    });

    test('sends an empty request body (include_revoked defaults false)',
        () async {
      final api = _FakeApi([_enumResp()]);
      await SessionsClient(api).enumerate(_account());
      expect(api.lastRequest!.toBytes(), isEmpty);
    });

    test('throws when the account has no access token', () async {
      final api = _FakeApi([_enumResp()]);
      expect(
        () => SessionsClient(api).enumerate(_account(token: null)),
        throwsA(isA<MissingAccessTokenException>()),
      );
    });
  });
}
