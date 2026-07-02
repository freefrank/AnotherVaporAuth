import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../services/image_disk_cache.dart';

/// An [ImageProvider] for Steam CDN images backed by [DiskImageCache]: bytes
/// come from disk instantly on a relaunch and from the network exactly once.
/// Steam asset URLs are content-hashed, so a URL's bytes never change — an
/// avatar update shows up as a *new URL*, i.e. a different provider key.
///
/// Decodes through the engine codec, so animated GIF avatars keep animating
/// (APNG frames still go through `AnimatedSteamImage`, which shares the same
/// disk cache).
class SteamImageProvider extends ImageProvider<SteamImageProvider> {
  final String url;
  const SteamImageProvider(this.url);

  @override
  Future<SteamImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<SteamImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      SteamImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(
      SteamImageProvider key, ImageDecoderCallback decode) async {
    final bytes = await DiskImageCache.instance.load(url);
    if (bytes == null) {
      // Evict the failed entry so a later rebuild retries (e.g. once
      // connectivity returns) instead of caching the error forever.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('image unavailable: $url');
    }
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Corrupt cached bytes: drop them so the next attempt redownloads.
      unawaited(DiskImageCache.instance.evict(url));
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SteamImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'SteamImageProvider("$url")';
}
