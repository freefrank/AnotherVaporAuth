import 'package:dio/dio.dart';

import 'debug_log.dart';

/// Thrown by [AvatarService.fetchEquippedItems] when the account's access
/// token is stale (HTTP 401); the caller should refresh the session and retry.
class FrameUnauthorized implements Exception {}

/// Equipped profile cosmetics resolved from GetProfileItemsEquipped.
class EquippedItems {
  final String? frameUrl; // avatar frame (often animated APNG)
  final String? animatedAvatarUrl; // animated avatar (APNG)
  const EquippedItems({this.frameUrl, this.animatedAvatarUrl});
}

/// Public profile bits resolved from the community XML.
class SteamProfile {
  final String? avatarUrl;
  final String? personaName; // display name / nickname
  const SteamProfile({this.avatarUrl, this.personaName});
}

/// Resolves a Steam profile avatar (and equipped avatar frame) without a Web
/// API key.
///
/// * Avatar: the public community profile XML
///   `https://steamcommunity.com/profiles/<steamid>?xml=1`, which exposes
///   `<avatarFull>` / `<avatarMedium>` CDN image URLs for public profiles.
/// * Avatar frame: `IPlayerService/GetProfileItemsEquipped`, authorized with the
///   account's own `access_token` (no key needed). The XML feed does not carry
///   the frame, so this is the only keyless source.
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
  static final RegExp _persona = RegExp(
      r'<steamID>(?:<!\[CDATA\[)?\s*(.*?)\s*(?:\]\]>)?</steamID>',
      dotAll: true);

  /// Resolves the public avatar URL + persona (display) name for [steamId] from
  /// the community profile XML. Fields are null if the profile is private /
  /// unreachable.
  Future<SteamProfile> fetchProfile(int steamId) async {
    if (steamId == 0) return const SteamProfile();
    try {
      final resp = await _dio.get<String>(
        'https://steamcommunity.com/profiles/$steamId',
        queryParameters: const {'xml': '1'},
        options: Options(responseType: ResponseType.plain),
      );
      final xml = resp.data ?? '';
      final url = (_full.firstMatch(xml) ?? _medium.firstMatch(xml))?.group(1);
      final persona = _persona.firstMatch(xml)?.group(1)?.trim();
      dlog('profile: $steamId avatar=${url ?? 'none'} persona="${persona ?? ''}"');
      return SteamProfile(
        avatarUrl: (url != null && url.startsWith('http')) ? url : null,
        personaName: (persona != null && persona.isNotEmpty) ? persona : null,
      );
    } catch (e) {
      dlog('profile fetch failed ($steamId): $e');
      return const SteamProfile();
    }
  }

  /// Returns the equipped avatar frame + animated avatar for [steamId] (either
  /// may be null if not equipped / unresolved). Uses the account's own
  /// [accessToken]; returns empty when no token is available. Throws
  /// [FrameUnauthorized] on HTTP 401 so the caller can refresh and retry.
  Future<EquippedItems> fetchEquippedItems(
      int steamId, String? accessToken) async {
    if (steamId == 0 || accessToken == null || accessToken.isEmpty) {
      return const EquippedItems();
    }
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://api.steampowered.com/IPlayerService/GetProfileItemsEquipped/v1/',
        queryParameters: {
          'access_token': accessToken,
          'steamid': '$steamId',
          'language': 'english',
        },
        options: Options(responseType: ResponseType.json),
      );
      final response = resp.data?['response'] as Map<String, dynamic>?;
      final frame = response?['avatar_frame'] as Map<String, dynamic>?;
      final anim = response?['animated_avatar'] as Map<String, dynamic>?;
      // Steam's convention is counter-intuitive: image_small is the ANIMATED
      // asset (APNG frame / GIF avatar), image_large is the static poster.
      final frameRaw =
          (frame?['image_small'] ?? frame?['image_large']) as String? ?? '';
      final animRaw =
          (anim?['image_small'] ?? anim?['image_large']) as String? ?? '';
      final frameUrl = _itemImageUrl(frameRaw);
      final animUrl = _itemImageUrl(animRaw);
      dlog('equipped: $steamId frame=${frameUrl ?? 'none'} '
          'anim=${animUrl ?? 'none'}');
      return EquippedItems(frameUrl: frameUrl, animatedAvatarUrl: animUrl);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        dlog('equipped: $steamId -> 401 (token stale, will refresh)');
        throw FrameUnauthorized();
      }
      dlog('equipped fetch failed ($steamId): $e');
      return const EquippedItems();
    } catch (e) {
      dlog('equipped fetch failed ($steamId): $e');
      return const EquippedItems();
    }
  }

  /// Builds a full CDN URL from a profile-item image path (the API returns a
  /// path relative to the community images root, e.g. `items/<appid>/<hash>.png`).
  static String? _itemImageUrl(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    p = p.replaceFirst(RegExp(r'^/+'), '');
    const base =
        'https://cdn.fastly.steamstatic.com/steamcommunity/public/images/';
    if (p.startsWith('images/')) p = p.substring('images/'.length);
    return '$base$p';
  }
}
