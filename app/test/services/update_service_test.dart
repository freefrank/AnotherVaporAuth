import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data' show Uint8List;

import 'package:ava/src/core/update_check.dart';
import 'package:ava/src/services/update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Dio whose adapter answers from a closure — no sockets anywhere.
Dio _fakeDio(Future<ResponseBody> Function() answer) {
  final dio = Dio(BaseOptions(baseUrl: 'https://unit.test'));
  dio.httpClientAdapter = _ClosureAdapter(answer);
  return dio;
}

class _ClosureAdapter implements HttpClientAdapter {
  _ClosureAdapter(this.answer);
  final Future<ResponseBody> Function() answer;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      answer();

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) =>
    ResponseBody.fromString(body, status,
        headers: {'content-type': ['application/json']});

void main() {
  test('a newer version in the table comes back available', () async {
    final svc = UpdateService(
        dio: _fakeDio(() async =>
            _json('{"channels":{"linux-appimage":{"version":"9.9.9"}}}')));
    final d = await svc.check(
        currentVersion: '1.2.0', channelKey: 'linux-appimage');
    expect(d.available, isTrue);
    expect(d.latest, '9.9.9');
  });

  test('network failure is silence, not an exception', () async {
    // The check runs at every launch; offline is the normal case, not an
    // error case. Anything escaping here would surface during startup.
    final svc = UpdateService(
        dio: _fakeDio(() async => throw const SocketException('offline')));
    final d = await svc.check(
        currentVersion: '1.2.0', channelKey: 'linux-appimage');
    expect(d, UpdateDecision.none);
  });

  test('non-200 and non-JSON both read as no information', () async {
    for (final answer in [
      () async => _json('{"error":"nope"}', status: 503),
      () async => ResponseBody.fromString('<html>captive portal</html>', 200,
          headers: {'content-type': ['text/html']}),
    ]) {
      final svc = UpdateService(dio: _fakeDio(answer));
      final d = await svc.check(
          currentVersion: '1.2.0', channelKey: 'linux-appimage');
      expect(d.available, isFalse);
    }
  });

  test('the dismissed version does not prompt again', () async {
    final svc = UpdateService(
        dio: _fakeDio(() async =>
            _json('{"channels":{"linux-appimage":{"version":"1.3.0"}}}')));
    final d = await svc.check(
      currentVersion: '1.2.0',
      channelKey: 'linux-appimage',
      dismissedVersion: '1.3.0',
    );
    expect(d.available, isFalse);
  });

  test('a hung endpoint resolves within the service timeout, silently',
      () async {
    // Never completes — the service's own receive timeout must cut it off.
    final svc = UpdateService(
        dio: _fakeDio(() => Completer<ResponseBody>().future
          ..timeout(const Duration(seconds: 30))));
    final d = await svc
        .check(currentVersion: '1.2.0', channelKey: 'linux-appimage')
        .timeout(const Duration(seconds: 15));
    expect(d, UpdateDecision.none);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
