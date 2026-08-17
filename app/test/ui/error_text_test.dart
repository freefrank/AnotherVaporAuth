import 'dart:async';
import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/error_text.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  RequestOptions req() => RequestOptions(path: '/mobileconf/getlist');

  group('describeError', () {
    test('the issue-#6 shape stops being a stack trace with a Retry button',
        () {
      // Verbatim what the confirmations tab put on screen: Dio's own message
      // is the string "null", and the cause it wrapped is the real story.
      final e = DioException(
        requestOptions: req(),
        type: DioExceptionType.unknown,
        error: const HandshakeException('Connection terminated during '
            'handshake'),
      );

      final text = describeError(l, e);

      expect(text, l.netErrTls);
      expect(text, isNot(contains('DioException')));
      expect(text, isNot(contains('HandshakeException')));
      expect(text, isNot(contains('null')));
    });

    test('a bare TLS failure reads the same as a wrapped one', () {
      expect(
          describeError(
              l, const HandshakeException('Connection terminated')),
          l.netErrTls);
    });

    test('a certificate failure is not lumped in with a cut handshake', () {
      // CertificateException is itself a TlsException, so order of the type
      // checks is what keeps these apart.
      expect(describeError(l, const CertificateException('self signed')),
          l.netErrCert);
      expect(
          describeError(
              l,
              DioException(
                  requestOptions: req(),
                  type: DioExceptionType.badCertificate)),
          l.netErrCert);
    });

    test('no route to the host reads as unreachable', () {
      expect(describeError(l, const SocketException('Failed host lookup')),
          l.netErrUnreachable);
      expect(
          describeError(
              l,
              DioException(
                requestOptions: req(),
                type: DioExceptionType.connectionError,
                error: const SocketException('Connection refused'),
              )),
          l.netErrUnreachable);
    });

    test('every timeout Dio has maps to the timeout message', () {
      for (final t in const [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(describeError(l, DioException(requestOptions: req(), type: t)),
            l.netErrTimeout,
            reason: '$t');
      }
      expect(describeError(l, TimeoutException('slow')), l.netErrTimeout);
    });

    test('an HTTP status from Steam is named', () {
      final e = DioException(
        requestOptions: req(),
        type: DioExceptionType.badResponse,
        response: Response<String>(requestOptions: req(), statusCode: 503),
      );

      expect(describeError(l, e), l.netErrServer(503));
      expect(describeError(l, e), contains('503'));
    });

    test("Steam's own message wins — we have nothing better to say", () {
      expect(
          describeError(
              l, SteamApiException(0, 'HTTP 405', 'GetActiveSessions')),
          'HTTP 405');
    });

    test('a wrapped exception with no cause still says something useful', () {
      expect(
          describeError(
              l,
              DioException(
                  requestOptions: req(), type: DioExceptionType.unknown)),
          l.netErrUnreachable);
    });

    test('anything we do not model keeps its own toString', () {
      // Deliberate: inventing a friendly sentence for an error we have not
      // understood hides a bug behind reassuring words.
      final e = StateError('payload entry escapes the install folder');

      expect(describeError(l, e), '$e');
      expect(describeError(l, e), contains('escapes the install folder'));
    });

    test('every message is a sentence, not a class name', () {
      for (final text in [
        l.netErrTls,
        l.netErrUnreachable,
        l.netErrTimeout,
        l.netErrCert,
        l.netErrServer(500),
      ]) {
        expect(text, isNot(contains('Exception')));
        expect(text.trim(), isNotEmpty);
      }
    });
  });
}
