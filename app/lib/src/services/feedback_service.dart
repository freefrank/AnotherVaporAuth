import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Relays user-initiated feedback to the developer's mailbox through the
/// ava-feedback Cloudflare Worker. Nothing is sent unless the user presses
/// send; the attached metadata is exactly the line shown in the dialog.
class FeedbackService {
  static const _endpoint = 'https://ava-feedback.dotslash.pro';

  // Not a secret (the repo is public) — keeps stray traffic off the endpoint.
  static const _clientToken = 'ava-feedback-v1';

  /// The metadata line attached to a report, e.g. "AVA 0.65.2 · android · zh".
  static Future<String> meta(String localeCode) async {
    final version = (await PackageInfo.fromPlatform()).version;
    return 'AVA $version · ${Platform.operatingSystem} · $localeCode';
  }

  /// Throws [DioException] (or [StateError] on a non-ok reply) on failure.
  static Future<void> send({
    required String message,
    required String contact,
    required String meta,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    try {
      final res = await dio.post<Map<String, dynamic>>(
        _endpoint,
        data: {'message': message, 'contact': contact, 'meta': meta},
        options: Options(headers: {'x-ava-client': _clientToken}),
      );
      if (res.data?['ok'] != true) {
        throw StateError('feedback relay replied: ${res.data}');
      }
    } finally {
      dio.close();
    }
  }
}
