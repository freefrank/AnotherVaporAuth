import 'dart:typed_data';

import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays a canned HTTP status + headers for every request, so we can pin
/// down how [SteamApiClient.callProtobuf] maps the `x-eresult` header (or its
/// absence) onto success / [SteamApiException].
class _FakeAdapter implements HttpClientAdapter {
  final int status;
  final Map<String, List<String>> headers;
  _FakeAdapter(this.status, this.headers);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromBytes(const [], status, headers: headers);

  @override
  void close({bool force = false}) {}
}

SteamApiClient _client(int status, Map<String, List<String>> headers) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
    ..httpClientAdapter = _FakeAdapter(status, headers);
  return SteamApiClient(dio: dio);
}

Future<ProtoReader> _call(SteamApiClient c) => c.callProtobuf(
    'IAuthenticationService', 'UpdateAuthSessionWithMobileConfirmation',
    request: ProtoWriter(), accessToken: 'tok');

void main() {
  test('HTTP 200 + x-eresult OK succeeds', () async {
    final r = await _call(_client(200, {
      'x-eresult': ['1']
    }));
    expect(r.parse(), isEmpty);
  });

  test('HTTP 200 without x-eresult is still treated as success', () async {
    final r = await _call(_client(200, {}));
    expect(r.parse(), isEmpty);
  });

  test('x-eresult AccessDenied throws with that eresult', () async {
    await expectLater(
      _call(_client(200, {
        'x-eresult': ['15']
      })),
      throwsA(isA<SteamApiException>()
          .having((e) => e.eresult, 'eresult', 15)),
    );
  });

  test('HTTP 401 without x-eresult must throw, not fake a success', () async {
    // An expired/invalid access token can come back as a bare 401 with no
    // x-eresult header; defaulting that to OK made approvals look successful
    // while Steam had rejected them.
    await expectLater(
      _call(_client(401, {})),
      throwsA(isA<SteamApiException>()),
    );
  });
}
