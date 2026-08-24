import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// The desktop window's saved geometry.
///
/// [bounds] is always the *restored* geometry — the size and position the
/// window returns to when un-maximized. Storing it separately from
/// [maximized] means quitting while maximized does not lose the size
/// underneath, which is what the user gets back when they un-maximize.
class WindowGeometry {
  final Rect bounds;
  final bool maximized;

  const WindowGeometry({required this.bounds, required this.maximized});

  Map<String, dynamic> toJson() => {
        'x': bounds.left,
        'y': bounds.top,
        'w': bounds.width,
        'h': bounds.height,
        'maximized': maximized,
      };

  /// Returns null for anything that is not a complete, finite, positive-sized
  /// record — a half-written file or a hand-edited one should restore the
  /// default window, not a zero-height sliver the user cannot grab.
  static WindowGeometry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    double? num_(Object? v) {
      final d = v is num ? v.toDouble() : null;
      return (d == null || !d.isFinite) ? null : d;
    }

    final x = num_(raw['x']);
    final y = num_(raw['y']);
    final w = num_(raw['w']);
    final h = num_(raw['h']);
    if (x == null || y == null || w == null || h == null) return null;
    if (w < minWindowSize.width || h < minWindowSize.height) return null;
    return WindowGeometry(
      bounds: Rect.fromLTWH(x, y, w, h),
      maximized: raw['maximized'] == true,
    );
  }
}

/// Smaller than this and the app is unusable; also the floor for a restored
/// window, so a saved sliver can never come back.
const minWindowSize = Size(720, 560);

/// Enough of the window's top edge must land inside a display for the user to
/// be able to grab and move it. A window peeking 20 logical pixels onto a
/// screen is, in practice, lost.
const _minVisible = 96.0;

/// Fits [saved] onto whichever of [displays] it belongs to.
///
/// Monitors get unplugged and resolutions change, so a position that was fine
/// last week can be entirely off-screen today — a window restored there is
/// invisible, and the user has no way to know the app even started. This
/// keeps the size the user chose and moves the window the least distance that
/// makes it reachable.
///
/// Returns null when [displays] is empty (no display information available),
/// meaning "do not restore a position at all" — the caller should centre.
Rect? fitToDisplays(Rect saved, List<Rect> displays) {
  if (displays.isEmpty) return null;

  // Already reachable on some display: leave it exactly where it was. Any
  // adjustment here would nudge windows on every launch.
  for (final d in displays) {
    final overlap = saved.intersect(d);
    if (overlap.width >= _minVisible && overlap.height >= _minVisible) {
      return saved;
    }
  }

  // Otherwise move it onto the nearest display, by distance between centres.
  var target = displays.first;
  var best = double.infinity;
  for (final d in displays) {
    final dx = saved.center.dx - d.center.dx;
    final dy = saved.center.dy - d.center.dy;
    final dist = dx * dx + dy * dy;
    if (dist < best) {
      best = dist;
      target = d;
    }
  }

  // Shrink before moving: a window wider than the display it is being sent to
  // cannot be positioned so that all of it is visible.
  final w = math.min(saved.width, target.width);
  final h = math.min(saved.height, target.height);
  final x = saved.left
      .clamp(target.left, math.max(target.left, target.right - w))
      .toDouble();
  final y = saved.top
      .clamp(target.top, math.max(target.top, target.bottom - h))
      .toDouble();
  return Rect.fromLTWH(x, y, w, h);
}
