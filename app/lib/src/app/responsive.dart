import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'screen_corners.dart';

/// Viewport-relative sizing so the UI scales proportionally instead of using
/// fixed pixel values.
///
/// Sizes are authored against a 390dp-wide reference (a typical phone). The
/// scale factor is the current width over that reference, clamped so very
/// narrow or very wide viewports (small phones, tablets, desktop) stay sane.
extension ResponsiveContext on BuildContext {
  static const double _refWidth = 390.0;
  static const double _min = 0.85;
  // Don't upscale beyond the reference width: large screens (tablets, unfolded
  // foldables) keep the base sizes and rely on the two-pane layout for space,
  // so the tablet proportions match the v0.56 design.
  static const double _max = 1.0;

  /// The viewport scale factor (1.0 ≈ a 390dp-wide phone).
  double get scale {
    final w = MediaQuery.sizeOf(this).width;
    return (w / _refWidth).clamp(_min, _max);
  }

  /// A design value scaled to the current viewport.
  double r(double value) => value * scale;

  /// [r] converted to physical pixels — for `Image.network(cacheWidth: …)` so
  /// network images decode at display size instead of full resolution.
  /// Rounded up to 32px buckets so live window resizes (desktop) don't thrash
  /// the image cache with a re-decode per pixel of width change.
  int rCache(double value) {
    final px = (r(value) * MediaQuery.devicePixelRatioOf(this)).ceil();
    return ((px + 31) ~/ 32) * 32;
  }

  /// [rInsets] plus the system-bar insets, for scroll views.
  ///
  /// Android 15 (targetSdk 35+) draws every app edge-to-edge and Android 16
  /// **ignores `windowOptOutEdgeToEdgeEnforcement`** — opting out is not an
  /// option, we target SDK 36. So content paints under the status bar and the
  /// gesture handle, and anything that would otherwise sit at the very top or
  /// bottom has to inset itself.
  ///
  /// Flutter does this automatically for a [BoxScrollView] **only when its
  /// `padding` is null**; passing an explicit padding — which every screen
  /// here does, for the design's own spacing — silently disables it. This
  /// helper adds it back.
  ///
  /// Self-adjusting by design: [MediaQuery.paddingOf] is what a [SafeArea]
  /// reads, and Scaffold already strips the top from its body's MediaQuery
  /// when there's an AppBar — so on those screens this degrades to a
  /// bottom-only inset with no per-screen decision. `padding` (not
  /// `viewPadding`) also means the bottom collapses to zero while the
  /// keyboard is up, where Scaffold has already resized the body.
  ///
  /// The bottom also clears the display's rounded corner
  /// ([ScreenCorners.bottomOf]), which no MediaQuery field describes. It is
  /// `max(system inset, corner radius)` and **not** their sum: the gesture
  /// pill's 24dp already sits inside the height the corner arc sweeps, so
  /// adding them would waste a visible strip on every screen.
  ///
  /// System insets are deliberately **not** multiplied by [scale]: they are
  /// physical affordances the OS measured, not design values.
  EdgeInsets rSafeInsets({
    double all = 0,
    double h = 0,
    double v = 0,
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    final base = rInsets(
        all: all, h: h, v: v, left: left, top: top, right: right, bottom: bottom);
    final sys = MediaQuery.paddingOf(this);
    return EdgeInsets.only(
      left: base.left + sys.left,
      top: base.top + sys.top,
      right: base.right + sys.right,
      bottom: base.bottom + math.max(sys.bottom, ScreenCorners.bottomOf(this)),
    );
  }

  /// How much further past the system inset the display's rounded corner
  /// reaches — 0 when the corner is already inside it.
  ///
  /// For widgets the Scaffold positions itself: `FloatingActionButtonLocation`
  /// already lifts a FAB clear of `minViewPadding.bottom`, so a corner-anchored
  /// FAB only needs the remainder. Applying [rSafeInsets] to it instead would
  /// double-count the system inset and float it too high.
  double get cornerOvershoot => math.max(
      0, ScreenCorners.bottomOf(this) - MediaQuery.paddingOf(this).bottom);

  /// Symmetric/all-sides scaled insets helper.
  EdgeInsets rInsets({
    double all = 0,
    double h = 0,
    double v = 0,
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    final s = scale;
    return EdgeInsets.only(
      left: (all + h + left) * s,
      top: (all + v + top) * s,
      right: (all + h + right) * s,
      bottom: (all + v + bottom) * s,
    );
  }
}
