import 'dart:convert';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/protocol/authenticator_linker.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake client that replays a queued response and records what was sent, so
/// the tests can assert on the exact wire fields of each request.
class _FakeApi extends SteamApiClient {
  final List<Object> responses; // ProtoReader, or SteamApiException to throw
  final List<String> calls = [];
  final List<Map<int, ProtoField>> requests = [];
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
    calls.add('$iface/$method');
    requests.add(ProtoReader(request.toBytes()).parse());
    final next = responses.removeAt(0);
    if (next is SteamApiException) throw next;
    return next as ProtoReader;
  }
}

/// A `CTwoFactor_AddAuthenticator_Response` — the same message Steam nests in
/// `replacement_token`.
ProtoWriter _addResponse({
  List<int> sharedSecret = const [1, 2, 3],
  String revocationCode = 'R54321',
  int status = 1,
}) =>
    ProtoWriter()
      ..writeBytes(1, sharedSecret)
      ..writeString(3, revocationCode)
      ..writeString(4, 'otpauth://totp/Steam')
      ..writeVarint(5, 1700000000)
      ..writeString(6, 'tester')
      ..writeString(7, 'gid-9')
      ..writeBytes(8, const [4, 5, 6]) // identity_secret
      ..writeBytes(9, const [7, 8, 9]) // secret_1
      ..writeVarint(10, status);

/// [success] null omits the field entirely — which is what Steam actually
/// does, `success` being an optional proto field it never bothers to set.
ProtoReader _continueResponse({bool? success = true, ProtoWriter? replacement}) {
  final w = ProtoWriter();
  if (success != null) w.writeBool(1, success);
  if (replacement != null) w.writeMessage(2, replacement);
  return ProtoReader(w.toBytes());
}

AuthenticatorLinker _linker(_FakeApi api) =>
    AuthenticatorLinker(api, SessionData(steamId: 76561190000000000, accessToken: 't'));

void main() {
  group('moveInStart', () {
    test('success=true reports the challenge email was sent', () async {
      final api = _FakeApi([ProtoReader((ProtoWriter()..writeBool(1, true)).toBytes())]);

      expect(await _linker(api).moveInStart(), LinkResult.challengeEmailSent);
      expect(api.calls, ['ITwoFactorService/RemoveAuthenticatorViaChallengeStart']);
    });

    // Regression: this is what Steam really sends. `success` is an optional
    // proto field it never sets, so a successful Start comes back eresult=OK
    // with a 0-byte body. Defaulting the missing field to false rejected every
    // successful call — the email went out, the user just saw "failed".
    test('an empty body is success — the eresult already said OK', () async {
      final api = _FakeApi([ProtoReader(ProtoWriter().toBytes())]);

      expect(await _linker(api).moveInStart(), LinkResult.challengeEmailSent);
    });

    test('only an explicit success=false is a failure', () async {
      final api = _FakeApi([ProtoReader((ProtoWriter()..writeBool(1, false)).toBytes())]);

      expect(await _linker(api).moveInStart(), LinkResult.generalFailure);
    });

    test('maps rate limiting and lockdown to their own results', () async {
      expect(
        await _linker(_FakeApi([SteamApiException(84, 'rate', 'Start')])).moveInStart(),
        LinkResult.rateLimited,
      );
      expect(
        await _linker(_FakeApi([SteamApiException(73, 'locked', 'Start')])).moveInStart(),
        LinkResult.accountLocked,
      );
    });
  });

  group('moveInContinue', () {
    test('sends the code with generate_new_token set — a move, not a removal',
        () async {
      final api = _FakeApi([_continueResponse(replacement: _addResponse())]);

      await _linker(api).moveInContinue('ABCDE');

      expect(api.calls, ['ITwoFactorService/RemoveAuthenticatorViaChallengeContinue']);
      final req = api.requests.single;
      expect(req[1]?.asString, 'ABCDE'); // sms_code
      // The whole point of the move-in: false here would detach Steam Guard
      // and land the account in a 15-day trade hold.
      expect(req[2]?.asBool, isTrue); // generate_new_token
      expect(req[3]?.asInt, 2); // version
    });

    test('unpacks replacement_token into an active account', () async {
      final api = _FakeApi([_continueResponse(replacement: _addResponse())]);
      final linker = _linker(api);

      expect(await linker.moveInContinue('ABCDE'), LinkResult.movedIn);

      final acc = linker.linkedAccount!;
      expect(acc.sharedSecret, base64.encode(const [1, 2, 3]));
      expect(acc.identitySecret, base64.encode(const [4, 5, 6]));
      expect(acc.secret1, base64.encode(const [7, 8, 9]));
      expect(acc.revocationCode, 'R54321');
      expect(acc.accountName, 'tester');
      expect(acc.tokenGid, 'gid-9');
      expect(acc.serverTime, 1700000000);
      expect(acc.status, 1);
      // The replacement token arrives activated — no finalize() step.
      expect(acc.fullyEnrolled, isTrue);
      // A move lands on this device, so it must carry this device's id.
      expect(acc.deviceId, isNotEmpty);
      expect(acc.session.steamId, 76561190000000000);
    });

    test('a rejected code leaves linkedAccount untouched', () async {
      final api = _FakeApi([_continueResponse(success: false)]);
      final linker = _linker(api);

      expect(await linker.moveInContinue('WRONG'), LinkResult.badChallengeCode);
      expect(linker.linkedAccount, isNull);
    });

    // Regression, and the worst failure this flow has: if Steam omits
    // `success` here the way it does in Start, treating that as a bad code
    // would tell the user to retry a challenge that ALREADY swapped the
    // token. Their old authenticator is dead, the retry cannot succeed, and
    // the account is locked out for good. The token's presence decides.
    test('a replacement_token with no success field still counts as moved',
        () async {
      final api = _FakeApi([
        _continueResponse(success: null, replacement: _addResponse()),
      ]);
      final linker = _linker(api);

      expect(await linker.moveInContinue('ABCDE'), LinkResult.movedIn);
      expect(linker.linkedAccount!.revocationCode, 'R54321');
    });

    test('success without a replacement_token is a failure, not a move', () async {
      final api = _FakeApi([_continueResponse(replacement: null)]);
      final linker = _linker(api);

      expect(await linker.moveInContinue('ABCDE'), LinkResult.badChallengeCode);
      expect(linker.linkedAccount, isNull);
    });

    test('a replacement_token with no shared_secret must never count as moved',
        () async {
      // Steam says OK but hands back nothing usable: adopting this would drop
      // the account with no way to generate codes.
      final api = _FakeApi([
        _continueResponse(replacement: _addResponse(sharedSecret: const [])),
      ]);
      final linker = _linker(api);

      expect(await linker.moveInContinue('ABCDE'), LinkResult.generalFailure);
      expect(linker.linkedAccount, isNull);
    });

    test('maps rate limiting and lockdown to their own results', () async {
      expect(
        await _linker(_FakeApi([SteamApiException(84, 'rate', 'Continue')]))
            .moveInContinue('ABCDE'),
        LinkResult.rateLimited,
      );
      expect(
        await _linker(_FakeApi([SteamApiException(73, 'locked', 'Continue')]))
            .moveInContinue('ABCDE'),
        LinkResult.accountLocked,
      );
    });
  });
}
