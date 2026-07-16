import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/channel.dart';
import '../../core/entitlement.dart';
import '../../services/play_channel.dart';

/// Load-state events from the native AdView ('ava/banner_events').
class _BannerEvents {
  static final _BannerEvents instance = _BannerEvents._();
  static const _channel = MethodChannel('ava/banner_events');
  final Map<int, void Function(bool loaded)> _listeners = {};

  _BannerEvents._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return;
      final args = (call.arguments as Map).cast<String, Object?>();
      _listeners[args['id'] as int]?.call(args['loaded'] == true);
    });
  }

  void listen(int viewId, void Function(bool loaded) cb) =>
      _listeners[viewId] = cb;

  void forget(int viewId) => _listeners.remove(viewId);
}

/// The home-screen banner slot. Renders nothing at all — zero height, no
/// placeholder hole — unless this is the play flavor, the user is on the
/// free tier, and the ad actually loaded. Never place this on a screen
/// with irreversible action buttons.
class AvaBannerSlot extends ConsumerWidget {
  const AvaBannerSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (avaChannel != AvaChannel.play ||
        defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    if (ref.watch(proStatusProvider) != ProStatus.free) {
      return const SizedBox.shrink();
    }
    return const _Banner();
  }
}

class _Banner extends ConsumerStatefulWidget {
  const _Banner();

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  int? _heightDp;
  int? _widthDp;
  bool _failed = false;
  bool _loaded = false;
  int? _viewId;

  Future<void> _measure(int widthDp) async {
    try {
      final h = await ref.read(playChannelProvider).bannerHeight(widthDp);
      if (mounted) setState(() => _heightDp = h);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    final id = _viewId;
    if (id != null) _BannerEvents.instance.forget(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final widthDp = constraints.maxWidth.floor();
      if (widthDp <= 0) return const SizedBox.shrink();
      if (_widthDp != widthDp) {
        _widthDp = widthDp;
        _heightDp = null;
        _measure(widthDp);
      }
      final height = _heightDp;
      if (height == null || height <= 0) return const SizedBox.shrink();
      final view = AndroidView(
        viewType: 'ava/banner',
        creationParams: {'adUnitId': kBannerAdUnitId, 'widthDp': widthDp},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          _viewId = id;
          _BannerEvents.instance.listen(id, (loaded) {
            if (!mounted) return;
            setState(() {
              _loaded = loaded;
              _failed = !loaded;
            });
          });
        },
      );
      // Keep the view alive (it has to load to report success) but collapse
      // the visible slot until the ad is actually there.
      return SafeArea(
        top: false,
        child: SizedBox(
          height: _loaded ? height.toDouble() : 1,
          child: view,
        ),
      );
    });
  }
}
