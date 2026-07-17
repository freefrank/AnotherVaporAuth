import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake client that records whether/how it was called and replays a queued
/// response. Used to prove that a missing access token fails *before* any
/// network call is attempted — never sends an empty-string access token.
class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
  bool called = false;
  String? lastAccessToken;
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
    called = true;
    lastAccessToken = accessToken;
    return responses.removeAt(0);
  }
}

SteamGuardAccount _account({String? accessToken, String? refreshToken}) =>
    SteamGuardAccount(
      sharedSecret: 'YQ==', // base64("a") — any validly-shaped secret
      session: SessionData(
        steamId: 76561198000000000,
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    );

void main() {
  group('SessionData token predicates', () {
    test('hasTokens stays true for a refresh-only session (renewal gate)',
        () {
      final s = SessionData(refreshToken: 'r');
      expect(s.hasTokens, isTrue);
    });

    test('hasAccessToken is false for a refresh-only session', () {
      final s = SessionData(refreshToken: 'r');
      expect(s.hasAccessToken, isFalse);
    });

    test('hasAccessToken is true once an access token is set', () {
      final s = SessionData(accessToken: 'a');
      expect(s.hasAccessToken, isTrue);
    });

    test('both are false when neither token is present', () {
      final s = SessionData(accessToken: '', refreshToken: null);
      expect(s.hasTokens, isFalse);
      expect(s.hasAccessToken, isFalse);
    });
  });

  group('QrApprovalClient — refresh-only session (no access token)', () {
    test('pendingLoginClientIds fails fast without calling the API',
        () async {
      final api = _FakeApi([]);
      final client = QrApprovalClient(api);
      final account = _account(refreshToken: 'r');

      await expectLater(
        client.pendingLoginClientIds(account),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.called, isFalse,
          reason: 'must not send a request with an empty access token');
    });

    test('sessionInfo fails fast without calling the API', () async {
      final api = _FakeApi([]);
      final client = QrApprovalClient(api);
      final account = _account(refreshToken: 'r');

      await expectLater(
        client.sessionInfo(account, 123),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.called, isFalse);
    });

    test('respondToSession fails fast without calling the API', () async {
      final api = _FakeApi([]);
      final client = QrApprovalClient(api);
      final account = _account(refreshToken: 'r');

      await expectLater(
        client.respondToSession(account,
            version: 1, clientId: 123, approve: true),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.called, isFalse);
    });

    test('respond() (scanned-QR entry point) also fails fast', () async {
      final api = _FakeApi([]);
      final client = QrApprovalClient(api);
      final account = _account(refreshToken: 'r');

      await expectLater(
        client.respond(account, const QrChallenge(1, 123), approve: true),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.called, isFalse);
    });

    test('a session with neither token also fails fast', () async {
      final api = _FakeApi([]);
      final client = QrApprovalClient(api);
      final account = _account();

      await expectLater(
        client.sessionInfo(account, 1),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.called, isFalse);
    });
  });

  group('pendingLoginClientIds — repeated client_ids field encodings', () {
    // Client ids are random uint64s — roughly half exceed 2^63-1 and arrive
    // as negative signed ints; both encodings must survive that.
    const idSmall = 123456789;
    const idHuge = -524256132778200960; // an unsigned-64 id, stored signed

    test('unpacked repeated varints are collected', () async {
      final w = ProtoWriter()
        ..writeUint64(1, idSmall)
        ..writeUint64(1, idHuge);
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final client = QrApprovalClient(api);

      final ids = await client.pendingLoginClientIds(
          _account(accessToken: 'atok'));
      expect(ids, [idSmall, idHuge]);
    });

    test('packed repeated varints are collected', () async {
      // Pack by stripping each writeUint64's 1-byte tag (field 1, wire 0).
      final packed = BytesBuilder();
      for (final v in [idSmall, idHuge]) {
        packed.add((ProtoWriter()..writeUint64(1, v)).toBytes().sublist(1));
      }
      final w = ProtoWriter()..writeBytes(1, packed.toBytes());
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final client = QrApprovalClient(api);

      final ids = await client.pendingLoginClientIds(
          _account(accessToken: 'atok'));
      expect(ids, [idSmall, idHuge]);
    });

    test('truncated packed payload throws ProtoParseException, not garbage',
        () async {
      // A varint cut mid-continuation must not silently under-read into a
      // bogus id the user could be asked to approve.
      final w = ProtoWriter()..writeBytes(1, const [0x87, 0x80]);
      final api = _FakeApi([ProtoReader(w.toBytes())]);
      final client = QrApprovalClient(api);

      await expectLater(
        client.pendingLoginClientIds(_account(accessToken: 'atok')),
        throwsA(isA<ProtoParseException>()),
      );
    });
  });

  group('QrApprovalClient — session with an access token', () {
    test('respondToSession sends the access token through and succeeds',
        () async {
      final api = _FakeApi([ProtoReader(Uint8List(0))]); // empty = success
      final client = QrApprovalClient(api);
      final account = _account(accessToken: 'atok', refreshToken: 'r');

      final ok = await client.respondToSession(account,
          version: 1, clientId: 123, approve: true);

      expect(ok, isTrue);
      expect(api.called, isTrue);
      expect(api.lastAccessToken, 'atok');
    });
  });
}
