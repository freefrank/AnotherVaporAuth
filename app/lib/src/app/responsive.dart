import 'package:flutter/widgets.dart';

/// Viewport-relative sizing so the UI scales proportionally instead of using
/// fixed pixel values.
///
/// Sizes are authored against a 390dp-wide reference (a typical phone). The
/// scale factor is the current width over that reference, clamped so very
/// narrow or very wide viewports (small phones, tablets, desktop) stay sane.
extension ResponsiveContext on BuildContext {
  static const double _refWidth = 390.0;
  static const double _min = 0.85;
  static const double _max = 1.35;

  /// The viewport scale factor (1.0 ≈ a 390dp-wide phone).
  double get scale {
    final w = MediaQuery.sizeOf(this).width;
    return (w / _refWidth).clamp(_min, _max);
  }

  /// A design value scaled to the current viewport.
  double r(double value) => value * scale;

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
