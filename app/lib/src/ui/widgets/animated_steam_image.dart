import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../../services/debug_log.dart';

/// A decoded (possibly animated) image: one or more frames with per-frame delays.
class SteamImageFrames {
  final List<ui.Image> frames;
  final List<int> delaysMs;
  final int totalMs;
  SteamImageFrames(this.frames, this.delaysMs)
      : totalMs = delaysMs.fold(0, (a, b) => a + b);
  bool get animated => frames.length > 1;
}

/// Raw frame data crossing the isolate boundary (ui.Image is not sendable).
class _RawFrame {
  final Uint8List rgba;
  final int width;
  final int height;
  final int delayMs;
  _RawFrame(this.rgba, this.width, this.height, this.delayMs);
}

/// Downloads + decodes (with caching) Steam profile images, including animated
/// APNG avatars / avatar frames that Flutter's built-in codec renders as a
/// single static frame. Decoding runs in a background isolate; the resulting
/// frames are shared across every widget that shows the same URL.
class SteamImageCache {
  SteamImageCache._();
  static final SteamImageCache instance = SteamImageCache._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.bytes,
  ));
  final Map<String, Future<SteamImageFrames?>> _cache = {};

  Future<SteamImageFrames?> load(String url) {
    return _cache.putIfAbsent(url, () => _fetchAndDecode(url));
  }

  Future<SteamImageFrames?> _fetchAndDecode(String url) async {
    try {
      final resp = await _dio.get<List<int>>(url);
      final bytes = Uint8List.fromList(resp.data ?? const []);
      if (bytes.isEmpty) return null;
      final raw = await Isolate.run(() => _decode(bytes));
      if (raw == null || raw.isEmpty) return null;
      final frames = <ui.Image>[];
      final delays = <int>[];
      for (final f in raw) {
        frames.add(await _toUiImage(f));
        delays.add(f.delayMs <= 0 ? 100 : f.delayMs);
      }
      dlog('steam-image: $url -> ${frames.length} frame(s)');
      return SteamImageFrames(frames, delays);
    } catch (e) {
      dlog('steam-image decode failed ($url): $e');
      _cache.remove(url); // allow a later retry
      return null;
    }
  }

  static Future<ui.Image> _toUiImage(_RawFrame f) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        f.rgba, f.width, f.height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  // Frames are only shown at small sizes (≤ ~68px logical); cap the decoded
  // dimension so a long animation (e.g. a 120-frame APNG) stays light on memory.
  static const int _maxDim = 192;

  /// Runs in an isolate: decode all frames to composited RGBA buffers,
  /// downscaling oversized frames.
  static List<_RawFrame>? _decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final out = <_RawFrame>[];
    for (final frame in decoded.frames) {
      var f = frame;
      final m = f.width > f.height ? f.width : f.height;
      if (m > _maxDim) {
        final scale = _maxDim / m;
        f = img.copyResize(frame,
            width: (f.width * scale).round(),
            height: (f.height * scale).round());
      }
      final rgba = f.getBytes(order: img.ChannelOrder.rgba);
      out.add(_RawFrame(rgba, f.width, f.height, frame.frameDuration));
    }
    return out;
  }
}

/// Renders a Steam profile image at [size], animating it if it is an animated
/// APNG. Falls back to [fallback] (or empty) while loading or on failure.
class AnimatedSteamImage extends StatefulWidget {
  final String url;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  const AnimatedSteamImage({
    super.key,
    required this.url,
    required this.size,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  @override
  State<AnimatedSteamImage> createState() => _AnimatedSteamImageState();
}

class _AnimatedSteamImageState extends State<AnimatedSteamImage>
    with SingleTickerProviderStateMixin {
  SteamImageFrames? _frames;
  Ticker? _ticker;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AnimatedSteamImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _ticker?.dispose();
      _ticker = null;
      _frames = null;
      _load();
    }
  }

  Future<void> _load() async {
    final f = await SteamImageCache.instance.load(widget.url);
    if (!mounted || f == null) return;
    setState(() => _frames = f);
    if (f.animated && f.totalMs > 0) {
      _ticker = createTicker((elapsed) {
        final idx = _indexAt(f, elapsed.inMilliseconds % f.totalMs);
        if (idx != _frameIndex) setState(() => _frameIndex = idx);
      })
        ..start();
    }
  }

  static int _indexAt(SteamImageFrames f, int t) {
    var acc = 0;
    for (var i = 0; i < f.frames.length; i++) {
      if (t < acc + f.delaysMs[i]) return i;
      acc += f.delaysMs[i];
    }
    return f.frames.length - 1;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  ui.Image? get _current {
    final f = _frames;
    if (f == null) return null;
    return f.frames[_frameIndex.clamp(0, f.frames.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final image = _current;
    final Widget child = image == null
        ? (widget.fallback ?? const SizedBox.shrink())
        : RawImage(
            image: image,
            width: widget.size,
            height: widget.size,
            fit: widget.fit,
          );
    final sized = SizedBox(width: widget.size, height: widget.size, child: child);
    if (widget.borderRadius == null) return sized;
    return ClipRRect(borderRadius: widget.borderRadius!, child: sized);
  }
}
