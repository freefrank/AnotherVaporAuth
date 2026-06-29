import 'package:dio/dio.dart';

/// Aligns local time with Steam's server time (TimeAligner equivalent).
///
/// The TOTP codes and confirmation hashes must use Steam server time. We query
/// `ITwoFactorService/QueryTime` once and cache the offset.
class SteamTime {
  static int _offsetSeconds = 0;
  static bool _aligned = false;

  /// Current Steam server time in unix seconds.
  static int get currentSteamTime =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + _offsetSeconds;

  static bool get isAligned => _aligned;

  /// Fetches the server time offset. Safe to call repeatedly; on failure it
  /// keeps the previous (or zero) offset so codes still work approximately.
  static Future<void> align({Dio? dio}) async {
    final client = dio ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));
    try {
      final resp = await client.post<Map<String, dynamic>>(
        'https://api.steampowered.com/ITwoFactorService/QueryTime/v0001',
        data: FormData.fromMap({'steamid': '0'}),
        options: Options(responseType: ResponseType.json),
      );
      final serverTime = int.tryParse(
          '${resp.data?['response']?['server_time'] ?? ''}');
      if (serverTime != null) {
        final local = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        _offsetSeconds = serverTime - local;
        _aligned = true;
      }
    } catch (_) {
      // Keep existing offset; do not block code generation on a network error.
    }
  }
}
