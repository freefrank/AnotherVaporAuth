import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'debug_log.dart';

/// A send that failed with a reason worth showing the user.
///
/// [message] is either the relay's own `error` string or a short description
/// of the transport failure — never a raw `DioException.toString()`, which is
/// a multi-line wall of developer advice.
class FeedbackException implements Exception {
  final String message;

  /// True when the request never reached the relay (DNS, connect, TLS,
  /// timeout), or something that isn't the relay answered. "Check your
  /// network" is only ever the right advice here.
  final bool transport;

  /// True when the relay answered with a 5xx — it is up, took the report, and
  /// broke on its own side (its SMTP hop failing is a 502 `send failed`).
  /// Telling the user to check their network here sends them after a fault
  /// they cannot see, let alone fix.
  final bool relayFault;

  const FeedbackException(
    this.message, {
    this.transport = false,
    this.relayFault = false,
  });

  @override
  String toString() => 'FeedbackException: $message';
}

/// Relays user-initiated feedback to the developer's mailbox through the
/// ava-feedback Cloudflare Worker. Nothing is sent unless the user presses
/// send; the attached metadata is exactly the line shown in the dialog.
class FeedbackService {
  static const _endpoint = 'https://ava-feedback.dotslash.pro';

  // Not a secret (the repo is public) — keeps stray traffic off the endpoint.
  static const _clientToken = 'ava-feedback-v1';

  /// The metadata line attached to a report, e.g. "AVA 0.65.2 · android · zh".
  ///
  /// Never throws: this runs in a post-frame callback and its result is the
  /// only thing identifying which build a report came from. A platform-channel
  /// hiccup used to leave it empty, which is indistinguishable from a report
  /// with no version at all.
  static Future<String> meta(String localeCode) async {
    var version = '?';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      dlog('feedback: PackageInfo unavailable ($e)');
    }
    return 'AVA $version · ${Platform.operatingSystem} · $localeCode';
  }

  /// Throws [FeedbackException] on any failure, with a reason fit to show.
  ///
  /// [dio] is injectable so tests exercise *this* function rather than a
  /// re-implementation of it; production always passes null and gets the
  /// client configured below.
  static Future<void> send({
    required String message,
    required String contact,
    required String meta,
    String? log,
    Dio? dio,
  }) async {
    final client = dio ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          // Never let Dio decide a status is fatal — this method reads every
          // body itself. The relay puts its reason in the body at *both* ends
          // of the range (`{"ok":false,"error":"empty message"}` on a 400,
          // `{"ok":false,"error":"send failed"}` on a 502 when its SMTP hop
          // dies). The default validateStatus turned those into opaque
          // DioExceptions and threw the explanation away with them.
          validateStatus: (_) => true,
        ));
    try {
      // Deliberately NOT `post<Map<String, dynamic>>`: that makes Dio cast the
      // body, and a reply that isn't a JSON object — a Cloudflare block page,
      // a captive-portal login form, any HTML — throws a TypeError, which is
      // not a DioException. It sailed past the handler below, past the UI's
      // type check, and logged nothing at all: a failure with no trace, which
      // is exactly what this method exists to prevent.
      final res = await client.post<dynamic>(
        _endpoint,
        data: {
          'message': message,
          'contact': contact,
          'meta': meta,
          if (log != null && log.isNotEmpty) 'log': log,
        },
        options: Options(headers: {'x-ava-client': _clientToken}),
      );
      final raw = res.data;
      final body = raw is Map ? raw : null;
      if (body?['ok'] == true) {
        dlog('feedback: sent (${message.length}B'
            '${log != null ? ' + ${log.length}B log' : ''})');
        return;
      }
      if (body == null) {
        // Something answered, but not the relay. Naming the content type is
        // what separates "Cloudflare blocked us" from "the relay is broken".
        final type = res.headers.value(Headers.contentTypeHeader) ?? 'unknown';
        dlog('feedback: HTTP ${res.statusCode} was not JSON '
            '($type, ${raw is String ? '${raw.length}B' : raw.runtimeType})');
        throw FeedbackException('HTTP ${res.statusCode} ($type)',
            transport: true);
      }
      final reason = body['error']?.toString() ?? 'HTTP ${res.statusCode}';
      final fault = (res.statusCode ?? 0) >= 500;
      dlog('feedback: relay ${fault ? 'failed' : 'refused'} — '
          'HTTP ${res.statusCode} $reason');
      throw FeedbackException(reason, relayFault: fault);
    } on DioException catch (e) {
      // Never reached the relay. Name the phase — connect vs receive vs a bad
      // certificate are different problems, and "check your network" is not
      // an answer when the relay simply is not reachable from here.
      dlog('feedback: transport failure ${e.type.name}'
          '${e.response?.statusCode != null ? ' HTTP ${e.response!.statusCode}' : ''}');
      throw FeedbackException(e.type.name, transport: true);
    } on FeedbackException {
      rethrow;
    } catch (e) {
      // Last resort. Anything that reaches here would otherwise leave the user
      // with "check your network" and the log with nothing.
      dlog('feedback: unexpected ${e.runtimeType} — $e');
      throw FeedbackException('${e.runtimeType}');
    } finally {
      // Only close what we opened — an injected client belongs to the caller.
      if (dio == null) client.close();
    }
  }
}
