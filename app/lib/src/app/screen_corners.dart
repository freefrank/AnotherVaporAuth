import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/debug_log.dart';

/// The display's bottom rounded-corner radius, published to the widget tree.
///
/// Flutter exposes no such thing: `MediaQuery`'s `padding` / `viewPadding` /
/// `systemGestureInsets` describe the system bars and the display cutout, and
/// nothing describes the corner arc. On a modern phone that arc clips whatever
/// sits in the bottom-left / bottom-right of an edge-to-edge screen — the last
/// card in a list, a corner-anchored FAB.
///
/// Android answers it via `WindowInsets.getRoundedCorner()` (API 31+), read
/// over the `ava/display` channel. Every other platform, and every Android
/// below 31, reports 0 — which is also what a widget test sees, so screens
/// behave exactly as before when nothing provides a value.
class ScreenCorners extends InheritedWidget {
  /// Bottom corner radius in logical pixels; 0 when unknown.
  final double bottom;

  const ScreenCorners({super.key, required this.bottom, required super.child});

  /// The radius for [context], or 0 where no [ScreenCornersScope] is above it
  /// (tests, desktop, pre-31 Android). Registers a dependency, so a fold that
  /// changes the radius rebuilds the readers.
  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenCorners>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(ScreenCorners oldWidget) =>
      oldWidget.bottom != bottom;
}

/// Queries the platform for the corner radius and republishes it whenever the
/// display metrics change.
///
/// The re-query is not optional: this app runs on a foldable, where unfolding
/// swaps to a panel with a different corner radius. A value read once at
/// startup would be wrong for the rest of the session.
class ScreenCornersScope extends StatefulWidget {
  final Widget child;

  /// Overridable so tests can pump a radius without a platform.
  final MethodChannel channel;

  const ScreenCornersScope({
    super.key,
    required this.child,
    this.channel = const MethodChannel('ava/display'),
  });

  @override
  State<ScreenCornersScope> createState() => _ScreenCornersScopeState();
}

class _ScreenCornersScopeState extends State<ScreenCornersScope>
    with WidgetsBindingObserver {
  double _radiusPx = 0;

  /// Retries left for a platform that answered "not ready" (-1). Bounded so a
  /// device that never attaches insets can't retry for the life of the process.
  int _retries = 8;
  Timer? _retry;

  /// ~1 frame at 60Hz. The decor view normally has its insets within one or
  /// two of these; 8 tries covers roughly the first quarter second.
  static const _retryInterval = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // initState runs during the first build, before Android has attached
    // window insets to the decor view — the first answer is normally -1.
    _refresh();
  }

  @override
  void dispose() {
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // A fold/unfold swaps to a panel with a different radius. Re-arm the
    // retries too: the new display's insets take a moment to settle.
    _retries = 8;
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background is the other moment a stale 0 can be
    // corrected without the user doing anything.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    int px;
    try {
      px = await widget.channel.invokeMethod<int>('bottomCornerRadius') ?? 0;
    } catch (e) {
      // MissingPluginException on a host without the channel, or any platform
      // error: a missing radius degrades to the old edge-to-edge layout rather
      // than crashing a screen the user is looking at — but it must not do so
      // silently, which is how a channel that never answered went unnoticed.
      dlog('screen-corners: query failed ($e)');
      return;
    }
    if (!mounted) return;
    if (px < 0) {
      // Insets aren't attached yet. Retry on a timer rather than a post-frame
      // callback: the latter only fires if something else is already driving
      // frames, and at this point in startup nothing is — the retry chain
      // silently stalled after exactly one attempt.
      if (_retries-- <= 0) {
        dlog('screen-corners: insets never became available');
        return;
      }
      _retry?.cancel();
      _retry = Timer(_retryInterval, _refresh);
      return;
    }
    if (px == _radiusPx) return;
    dlog('screen-corners: bottom radius ${px}px '
        '(${(px / MediaQuery.devicePixelRatioOf(context)).toStringAsFixed(1)}dp)');
    setState(() => _radiusPx = px.toDouble());
  }

  @override
  Widget build(BuildContext context) => ScreenCorners(
        // The platform answers in physical pixels; everything above this line
        // is logical.
        bottom: _radiusPx == 0
            ? 0
            : _radiusPx / MediaQuery.devicePixelRatioOf(context),
        child: widget.child,
      );
}
