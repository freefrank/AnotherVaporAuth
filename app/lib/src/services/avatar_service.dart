import 'package:dio/dio.dart';

import 'debug_log.dart';

/// Resolves a Steam profile avatar URL without requiring a Web API key, using
/// the public community profile XML:
/// `https://steamcommunity.com/profiles/<steamid>?xml=1`, which exposes
/// `<avatarFull>` / `<avatarMedium>` CDN image URLs for public profiles.
class AvatarService {
  final Dio _dio;
  AvatarService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  static final RegExp _full =
      RegExp(r'<avatarFull>(?:<!\[CDATA\[)?\s*(http[^\]<]+?)\s*(?:\]\]>)?</avatarFull>');
  static final RegExp _medium =
      RegExp(r'<avatarMedium>(?:<!\[CDATA\[)?\s*(http[^\]<]+?)\s*(?:\]\]>)?</avatarMedium>');

  /// Returns the full avatar URL for [steamId], or null if it can't be resolved
  /// (private profile, network error, etc.).
  Future<String?> fetchAvatarUrl(int steamId) async {
    if (steamId == 0) return null;
    try {
      final resp = await _dio.get<String>(
        'https://steamcommunity.com/profiles/$steamId',
        queryParameters: const {'xml': '1'},
        options: Options(responseType: ResponseType.plain),
      );
      final xml = resp.data ?? '';
      final url = (_full.firstMatch(xml) ?? _medium.firstMatch(xml))?.group(1);
      dlog('avatar: $steamId -> ${url ?? 'none'}');
      return (url != null && url.startsWith('http')) ? url : null;
    } catch (e) {
      dlog('avatar fetch failed ($steamId): $e');
      return null;
    }
  }
}
