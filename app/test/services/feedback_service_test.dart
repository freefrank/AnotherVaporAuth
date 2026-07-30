import 'dart:typed_data';

import 'package:ava/src/services/feedback_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays one canned reply for the relay POST.
class _Adapter implements HttpClientAdapter {
  final int status;
  final String body;
  final DioExceptionType? throwType;
  final String contentType;
  _Adapter(this.status, this.body,
      {this.throwType, this.contentType = Headers.jsonContentType});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (throwType != null) {
      throw DioException(requestOptions: options, type: throwType!);
    }
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Mirrors the production client's status policy — send() reads every body
/// itself, so Dio must never pre-judge a status.
Dio _dio(_Adapter adapter) =>
    Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;

/// Drives the real [FeedbackService.send] against a canned relay reply.
Future<void> _send(_Adapter adapter) => FeedbackService.send(
      message: 'hi',
      contact: '',
      meta: 'AVA 0.0.0 · android · en',
      dio: _dio(adapter),
    );

void main() {
  group('FeedbackException', () {
    test('a transport failure is flagged as one', () {
      const e = FeedbackException('connectionTimeout', transport: true);
      expect(e.transport, isTrue);
      // The UI branches on this: "check your network" is the wrong advice for
      // a relay that answered and refused.
      expect(e.message, 'connectionTimeout');
    });

    test('a refusal is not a transport failure', () {
      const e = FeedbackException('empty message');
      expect(e.transport, isFalse);
    });
  });

  group('relay contract', () {
    test('ok:true succeeds', () async {
      await _send(_Adapter(200, '{"ok":true}'));
    });

    test("a 4xx surfaces the relay's own error string, not a bare status",
        () async {
      // The default validateStatus threw a DioException here and threw the
      // explanation away with it — the whole reason a failed report was
      // undiagnosable.
      await expectLater(
        _send(_Adapter(400, '{"ok":false,"error":"empty message"}')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.message, 'message', 'empty message')
            .having((e) => e.transport, 'transport', isFalse)),
      );
    });

    test('a 403 from the client-token gate reaches the user verbatim',
        () async {
      await expectLater(
        _send(_Adapter(403, '{"ok":false,"error":"unknown client"}')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.message, 'message', 'unknown client')),
      );
    });

    test('a non-ok reply with no error string falls back to the status',
        () async {
      await expectLater(
        _send(_Adapter(200, '{"ok":false}')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.message, 'message', 'HTTP 200')),
      );
    });

    test('never reaching the relay is flagged transport, and names the phase',
        () async {
      await expectLater(
        _send(_Adapter(0, '',
            throwType: DioExceptionType.connectionTimeout)),
        throwsA(isA<FeedbackException>()
            .having((e) => e.transport, 'transport', isTrue)
            .having((e) => e.message, 'message', 'connectionTimeout')),
      );
    });
  });

  group('a reply that is not the relay', () {
    test('an HTML block page is reported, not swallowed', () async {
      // What a Cloudflare/WAF/captive-portal interception looks like. Asking
      // Dio for a Map here threw a TypeError — not a DioException — which
      // escaped every handler and left the debug log empty.
      await expectLater(
        _send(_Adapter(403, '<html><body>Access denied</body></html>',
            contentType: 'text/html')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.transport, 'transport', isTrue)
            .having((e) => e.message, 'message', contains('text/html'))),
      );
    });

    test('an empty body is reported rather than read as success', () async {
      await expectLater(
        _send(_Adapter(200, '', contentType: 'text/plain')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.transport, 'transport', isTrue)),
      );
    });

    test('a JSON array (not an object) does not crash the parse', () async {
      await expectLater(
        _send(_Adapter(200, '[]')),
        throwsA(isA<FeedbackException>()),
      );
    });
  });

  group('a 5xx is the relay breaking, not the user\'s network', () {
    test('502 send failed surfaces as a relay fault', () async {
      // Exactly what the worker returns when its SMTP hop fails
      // (infra/feedback-worker/src/index.js: `return bad(502, "send failed")`).
      // Reporting this as a transport failure told the user to check a network
      // that was working fine.
      await expectLater(
        _send(_Adapter(502, '{"ok":false,"error":"send failed"}')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.relayFault, 'relayFault', isTrue)
            .having((e) => e.transport, 'transport', isFalse)
            .having((e) => e.message, 'message', 'send failed')),
      );
    });

    test('a 4xx stays a refusal, not a relay fault', () async {
      await expectLater(
        _send(_Adapter(413, '{"ok":false,"error":"too long"}')),
        throwsA(isA<FeedbackException>()
            .having((e) => e.relayFault, 'relayFault', isFalse)),
      );
    });
  });
}
