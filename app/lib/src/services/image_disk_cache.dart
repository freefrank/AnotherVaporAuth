import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:path_provider/path_provider.dart';

import 'debug_log.dart';

/// Hosts that legitimately serve Steam avatar / item-image assets. A maFile
/// is untrusted input (it can be edited or forged before import), so the
/// avatar/avatarFrame/animatedAvatar URLs it carries must never be fetched
/// as-is — that would let a malicious file make this app issue a request to
/// an arbitrary attacker-controlled URL (SSRF) and write the response to
/// disk. Only Steam's own CDN, over https, is allowed.
///
/// `*.steamstatic.com` covers the observed real-world hosts (see
/// `avatar_service.dart` / `steam_item.dart`): `avatars.steamstatic.com`,
/// `avatars.akamai.steamstatic.com`, `avatars.cloudflare.steamstatic.com`,
/// `avatars.fastly.steamstatic.com`, `cdn.fastly.steamstatic.com`,
/// `community.fastly.steamstatic.com`, `community.cloudflare.steamstatic.com`.
/// `steamcdn-a.akamaihd.net` is the legacy CDN host some old profile XML
/// still points at.
bool isAllowedImageHost(String url) {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } catch (_) {
    return false;
  }
  if (uri.scheme.toLowerCase() != 'https') return false;
  var host = uri.host.toLowerCase();
  // A trailing dot denotes the DNS root and is otherwise equivalent
  // (`steamstatic.com.` == `steamstatic.com`); strip it before comparing.
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);
  if (host.isEmpty) return false;
  const exactAllowed = {
    'steamstatic.com',
    'steamcdn-a.akamaihd.net',
  };
  if (exactAllowed.contains(host)) return true;
  // endsWith('.steamstatic.com') requires the dot, so a look-alike like
  // `steamstatic.com.evil.example` or `notsteamstatic.com` is rejected.
  return host.endsWith('.steamstatic.com');
}

/// Hard cap on a single downloaded image: a forged/compromised maFile must
/// not be able to make this app pull down and store an arbitrarily large
/// payload.
const int maxCachedImageBytes = 2 * 1024 * 1024; // 2 MiB

/// A tiny content-addressed disk cache for Steam CDN images (avatars, avatar
/// frames), so a relaunch shows them instantly instead of re-downloading.
///
/// Steam asset URLs embed a content hash (`avatars/<hash>_full.jpg`,
/// `items/<appid>/<hash>.png`), so the bytes behind a URL never change and
/// need no revalidation — an avatar *update* arrives as a URL change (already
/// detected by the background profile refresh), which is simply a cache miss
/// here. Files are keyed by `sha1(url)`, written atomically, touched on read
/// and pruned by age, so abandoned assets don't accumulate forever.
class DiskImageCache {
  DiskImageCache({Dio? dio, Future<Directory> Function()? baseDir})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.bytes,
            )),
        _baseDir = baseDir ?? _defaultDir;

  static final DiskImageCache instance = DiskImageCache();

  final Dio _dio;
  final Future<Directory> Function() _baseDir;
  Future<Directory>? _dir;
  final Map<String, Future<Uint8List?>> _inflight = {};

  static Future<Directory> _defaultDir() async => Directory(
      '${(await getApplicationSupportDirectory()).path}/image_cache');

  Future<Directory> _cacheDir() => _dir ??= () async {
        final d = await _baseDir();
        await d.create(recursive: true);
        return d;
      }();

  File _fileFor(Directory dir, String url) =>
      File('${dir.path}/${hashlib.sha1.string(url).hex()}');

  /// The bytes for [url]: from disk when cached, downloaded (and stored) on a
  /// miss. Returns null when unavailable (e.g. offline and not cached).
  /// Concurrent requests for the same URL share one download.
  Future<Uint8List?> load(String url) {
    final pending = _inflight[url];
    if (pending != null) return pending;
    // Block body on purpose: an expression body would RETURN the removed
    // value — this very future — and whenComplete awaits a returned future,
    // deadlocking the load on itself.
    final fut = _load(url).whenComplete(() {
      _inflight.remove(url);
    });
    _inflight[url] = fut;
    return fut;
  }

  Future<Uint8List?> _load(String url) async {
    Directory dir;
    try {
      dir = await _cacheDir();
    } catch (e) {
      dlog('image-cache: no cache dir ($e), fetching direct');
      return _download(url, into: null);
    }
    final f = _fileFor(dir, url);
    try {
      final bytes = await f.readAsBytes();
      if (bytes.isNotEmpty) {
        // Touch for the age-based prune; best effort (fails on some FSes).
        unawaited(
            f.setLastModified(DateTime.now()).then((_) {}, onError: (_) {}));
        return bytes;
      }
    } catch (_) {/* not cached / unreadable — go to the network */}
    return _download(url, into: f);
  }

  Future<Uint8List?> _download(String url, {required File? into}) async {
    if (!isAllowedImageHost(url)) {
      dlog('image-cache: refusing non-Steam-CDN host ($url)');
      return null;
    }
    final cancelToken = CancelToken();
    try {
      final resp = await _dio.get<List<int>>(
        url,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // Belt-and-suspenders size cap: bail as soon as either the
          // advertised Content-Length or the bytes actually streamed so far
          // exceed the limit, so an oversized response is never fully
          // buffered just to be thrown away.
          if (total > maxCachedImageBytes || received > maxCachedImageBytes) {
            cancelToken.cancel('image exceeds $maxCachedImageBytes bytes');
          }
        },
      );
      final bytes = Uint8List.fromList(resp.data ?? const []);
      if (bytes.isEmpty || bytes.length > maxCachedImageBytes) return null;
      if (into != null) {
        // Atomic write: a crash mid-write must not leave a torn cache file.
        final tmp = File('${into.path}.${bytes.length}.tmp');
        try {
          await tmp.writeAsBytes(bytes, flush: true);
          await tmp.rename(into.path);
        } catch (_) {/* cache write failure is not a load failure */}
      }
      return bytes;
    } catch (e) {
      dlog('image-cache: fetch failed ($url): $e');
      return null;
    }
  }

  /// Drops the cached entry for [url] (e.g. the stored bytes fail to decode).
  Future<void> evict(String url) async {
    try {
      await _fileFor(await _cacheDir(), url).delete();
    } catch (_) {}
  }

  /// Deletes entries not read or written within [maxAge]. Call once per
  /// launch, fire-and-forget.
  Future<void> prune({Duration maxAge = const Duration(days: 60)}) async {
    try {
      final dir = await _cacheDir();
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final e in dir.list()) {
        if (e is! File) continue;
        try {
          final isTmp = e.path.endsWith('.tmp');
          if (isTmp || (await e.stat()).modified.isBefore(cutoff)) {
            await e.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
