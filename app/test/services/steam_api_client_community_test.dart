import 'dart:typed_data';

import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays a canned HTTP status + body + headers for every request, so we can
/// pin down how the community JSON helpers map the HTTP status onto success /
/// [CommunityAuthException] / [SteamApiException] — a 302/401 empty body must
/// never fall through and parse as a success-shaped `{}`.
class _FakeAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  final Map<String, List<String>> headers;
  _FakeAdapter(this.status, this.body, this.headers);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, status, headers: headers);

  @override
  void close({bool force = false}) {}
}

SteamApiClient _client(int status, String body,
    [Map<String, List<String>> headers = const {}]) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
    ..httpClientAdapter = _FakeAdapter(status, body, headers);
  return SteamApiClient(dio: dio);
}

/// Replays a fixed sequence of responses (one per request) and records the
/// requested URLs — needed for [SteamApiClient.communityGetText], which
/// follows redirects itself.
class _SeqAdapter implements HttpClientAdapter {
  final List<(int, String, Map<String, List<String>>)> responses;
  final urls = <String>[];
  _SeqAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    urls.add(options.uri.toString());
    final (status, body, headers) = responses.removeAt(0);
    return ResponseBody.fromString(body, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

SteamApiClient _seqClient(_SeqAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
    ..httpClientAdapter = adapter;
  return SteamApiClient(dio: dio);
}

void main() {
  // Both helpers share the status gate; every case must hold for GET and POST.
  for (final verb in ['GET', 'POST']) {
    Future<Map<String, dynamic>> call(SteamApiClient c) => verb == 'GET'
        ? c.communityGetJson('/mobileconf/getlist', {'tag': 'list'})
        : c.communityPostJson('/mobileconf/ajaxop', {'tag': 'allow'});

    group('community${verb}Json status gate', () {
      test('200 with an empty body stays a plain success {}', () async {
        expect(await call(_client(200, '')), isEmpty);
      });

      test('200 with a bare [] (removelisting success shape) stays {}',
          () async {
        expect(await call(_client(200, '[]')), isEmpty);
      });

      test('200 with a JSON object decodes normally', () async {
        expect(await call(_client(200, '{"success":true}')),
            {'success': true});
      });

      test('302 to the login page throws CommunityAuthException', () async {
        await expectLater(
          call(_client(302, '', {
            'location': ['/login/home/']
          })),
          throwsA(isA<CommunityAuthException>()
              .having((e) => e.status, 'status', 302)),
        );
      });

      test('bare 401 throws CommunityAuthException, not {}', () async {
        await expectLater(
          call(_client(401, '')),
          throwsA(isA<CommunityAuthException>()
              .having((e) => e.status, 'status', 401)),
        );
      });

      test('403 throws CommunityAuthException', () async {
        await expectLater(
          call(_client(403, '')),
          throwsA(isA<CommunityAuthException>()
              .having((e) => e.status, 'status', 403)),
        );
      });

      test('non-auth non-2xx (404) throws SteamApiException', () async {
        await expectLater(
          call(_client(404, '')),
          throwsA(isA<SteamApiException>()
              .having((e) => e.message, 'message', 'HTTP 404')
              .having((e) => e.httpStatus, 'httpStatus', 404)),
        );
      });

      test('302 to steammobile://lostauth throws CommunityAuthException',
          () async {
        // Steam's other stale-mobile-session bounce: the URI has no path, so
        // the '/login' check alone would misclassify it as a plain failure.
        await expectLater(
          call(_client(302, '', {
            'location': ['steammobile://lostauth']
          })),
          throwsA(isA<CommunityAuthException>()
              .having((e) => e.status, 'status', 302)),
        );
      });

      test('302 off the login page (eligibilitycheck) throws SteamApiException',
          () async {
        await expectLater(
          call(_client(302, '', {
            'location': ['/market/eligibilitycheck/?goto=%2Fmarket%2F']
          })),
          throwsA(isA<SteamApiException>()
              .having((e) => e.message, 'message', 'HTTP 302')),
        );
      });

      test('4xx with a JSON diagnostic body returns the parsed map', () async {
        // Steam reports command failures like sellitem's "too many listings
        // pending confirmation" as a 400 with a JSON body — the message must
        // reach the caller, not vanish into a bare HTTP error.
        expect(
          await call(_client(400,
              '{"success":false,"message":"You have too many listings pending confirmation"}')),
          {
            'success': false,
            'message': 'You have too many listings pending confirmation',
          },
        );
      });

      test('4xx with a non-object JSON body throws SteamApiException',
          () async {
        await expectLater(
          call(_client(400, '[]')),
          throwsA(isA<SteamApiException>()
              .having((e) => e.message, 'message', 'HTTP 400')),
        );
      });
    });
  }

  group('communityGetText auth detection', () {
    test('302 to the login page throws CommunityAuthException', () async {
      final adapter = _SeqAdapter([
        (302, '', {'location': ['/login/home/?goto=%2Fmarket%2F']}),
      ]);
      await expectLater(
        _seqClient(adapter).communityGetText('/market/'),
        throwsA(isA<CommunityAuthException>()
            .having((e) => e.status, 'status', 302)),
      );
    });

    test('bare 401 throws CommunityAuthException', () async {
      final adapter = _SeqAdapter([(401, '', {})]);
      await expectLater(
        _seqClient(adapter).communityGetText('/market/'),
        throwsA(isA<CommunityAuthException>()
            .having((e) => e.status, 'status', 401)),
      );
    });

    test('same-origin non-login redirect is still followed', () async {
      // The inventory page bounces through /market/eligibilitycheck — that
      // redirect is not an auth failure and must keep working.
      final adapter = _SeqAdapter([
        (302, '', {'location': ['/market/eligibilitycheck/?goto=%2Fmarket%2F']}),
        (200, '<html>ok</html>', {}),
      ]);
      expect(await _seqClient(adapter).communityGetText('/market/'),
          '<html>ok</html>');
      expect(adapter.urls, hasLength(2));
      expect(adapter.urls[1], contains('/market/eligibilitycheck'));
    });
  });

  group('callProtobuf httpStatus', () {
    test('bare 401 with no x-eresult carries httpStatus 401', () async {
      // The structural signal isSessionDeadError keys on — an expired token
      // surfaces as a naked 401 with no eresult header.
      await expectLater(
        _client(401, '').callProtobuf('IAuthenticationService', 'Whatever',
            request: ProtoWriter()),
        throwsA(isA<SteamApiException>()
            .having((e) => e.httpStatus, 'httpStatus', 401)),
      );
    });

    test('eresult failure leaves httpStatus null', () async {
      // A denied call with a real eresult is not a transport-level failure;
      // httpStatus must stay null so it never reads as a dead session.
      await expectLater(
        _client(200, '', {
          'x-eresult': ['15']
        }).callProtobuf('IAuthenticationService', 'Whatever',
            request: ProtoWriter()),
        throwsA(isA<SteamApiException>()
            .having((e) => e.eresult, 'eresult', 15)
            .having((e) => e.httpStatus, 'httpStatus', isNull)),
      );
    });
  });

  group('apiGetJson', () {
    test('bare 401 carries httpStatus 401', () async {
      await expectLater(
        _client(401, '').apiGetJson('IEconService', 'GetTradeOffers', {}),
        throwsA(isA<SteamApiException>()
            .having((e) => e.httpStatus, 'httpStatus', 401)),
      );
    });
  });

  group('isSessionDeadError', () {
    test('MissingAccessTokenException means a dead session', () {
      expect(isSessionDeadError(const MissingAccessTokenException()), isTrue);
    });

    test('CommunityAuthException means a dead session', () {
      expect(
          isSessionDeadError(
              const CommunityAuthException(401, '/mobileconf/getlist')),
          isTrue);
    });

    test('SteamApiException with httpStatus 401/403 means a dead session', () {
      expect(
          isSessionDeadError(SteamApiException(
              2, 'HTTP 401', 'GetTradeOffers', httpStatus: 401)),
          isTrue);
      expect(
          isSessionDeadError(SteamApiException(
              2, 'HTTP 403', 'GetTradeOffers', httpStatus: 403)),
          isTrue);
    });

    test('SteamApiException with httpStatus 404 does not', () {
      expect(
          isSessionDeadError(SteamApiException(
              2, 'HTTP 404', 'GetTradeOffers', httpStatus: 404)),
          isFalse);
    });

    test('eresult failure (null httpStatus) does not — even when the message '
        'mentions HTTP 401', () {
      // The old string-match on message would have misclassified this one.
      expect(
          isSessionDeadError(
              SteamApiException(15, 'quoting "HTTP 401"', 'GetTradeOffers')),
          isFalse);
    });

    test('unrelated errors do not', () {
      expect(isSessionDeadError(const FormatException('nope')), isFalse);
    });
  });
}
