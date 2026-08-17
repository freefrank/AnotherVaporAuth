import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';
import '../services/steam_api_client.dart';

/// User-facing text for a thrown object.
///
/// [SteamApiClient] logs transport failures and rethrows them untouched, on
/// purpose — callers need the real exception to tell a dead session from a
/// dead network. What went wrong is that every catch site then interpolated
/// `'$e'` straight into a message, so a phone on a filtered network was shown
///
///     错误: DioException [unknown]: null
///     Error: HandshakeException: Connection terminated during handshake
///
/// which is a stack trace with a Retry button under it (issue #6). It names
/// nothing the reader can act on, and "null" reads like the app broke rather
/// than the network.
///
/// Everything transport-level gets a sentence about what happened and what to
/// try. Anything else — a bug, an unmodelled failure — still falls through to
/// its own `toString()`, because inventing a friendly message for an error we
/// do not understand only hides it.
String describeError(AppLocalizations l, Object error) =>
    _describe(l, error) ?? '$error';

String? _describe(AppLocalizations l, Object error) {
  // Steam answered and said why. Its own message beats anything we'd write.
  if (error is SteamApiException) return error.message;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return l.netErrTimeout;
      case DioExceptionType.badCertificate:
        return l.netErrCert;
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        return code == null ? l.netErrUnreachable : l.netErrServer(code);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      case DioExceptionType.cancel:
        // The interesting exception is the one Dio wrapped: `unknown` is what
        // a TLS reset arrives as, and its own message is literally "null".
        final inner = error.error;
        return inner == null ? l.netErrUnreachable : _describe(l, inner);
    }
  }

  // CertificateException is a TlsException too, so it has to be asked first.
  if (error is CertificateException) return l.netErrCert;
  if (error is HandshakeException) return l.netErrTls;
  if (error is TlsException) return l.netErrTls;
  if (error is SocketException) return l.netErrUnreachable;
  if (error is TimeoutException) return l.netErrTimeout;
  if (error is HttpException) return l.netErrUnreachable;

  return null;
}
