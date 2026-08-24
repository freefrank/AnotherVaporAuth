import 'dart:ui';

import 'package:ava/src/core/window_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

/// A laptop screen at the origin and an external monitor to its right, the
/// arrangement that produces most of the interesting cases.
const _laptop = Rect.fromLTWH(0, 0, 1920, 1080);
const _external = Rect.fromLTWH(1920, 0, 2560, 1440);

void main() {
  group('fitToDisplays', () {
    test('a window already on screen is not nudged at all', () {
      // Launch-time adjustment must be a no-op in the common case, or the
      // window creeps a few pixels on every start.
      const saved = Rect.fromLTWH(100, 100, 1280, 720);

      expect(fitToDisplays(saved, const [_laptop]), saved);
    });

    test('a window on the second monitor stays there', () {
      const saved = Rect.fromLTWH(2200, 300, 1280, 720);

      expect(fitToDisplays(saved, const [_laptop, _external]), saved);
    });

    test('the monitor it lived on is gone — it comes back to the laptop', () {
      // Saved on the external display, which has since been unplugged.
      const saved = Rect.fromLTWH(2200, 300, 1280, 720);

      final fitted = fitToDisplays(saved, const [_laptop])!;

      expect(_laptop.contains(fitted.topLeft), isTrue);
      expect(_laptop.contains(fitted.bottomRight - const Offset(1, 1)), isTrue);
      expect(fitted.size, saved.size, reason: 'the size the user chose stays');
    });

    test('a negative position from a display that was to the left is rescued',
        () {
      // Monitors arranged to the *left* of the primary give negative
      // coordinates; unplug that one and the window is off in the void.
      const saved = Rect.fromLTWH(-1800, 200, 1280, 720);

      final fitted = fitToDisplays(saved, const [_laptop])!;

      expect(fitted.left, greaterThanOrEqualTo(_laptop.left));
      expect(fitted.size, saved.size);
    });

    test('a window barely peeking on screen counts as lost', () {
      // 20px of overlap is technically visible and practically unusable.
      const saved = Rect.fromLTWH(1900, 1060, 1280, 720);

      final fitted = fitToDisplays(saved, const [_laptop])!;

      expect(fitted, isNot(saved));
      expect(fitted.bottom, lessThanOrEqualTo(_laptop.bottom));
    });

    test('it moves to the nearest display, not simply the first', () {
      // Sitting just past the right edge of the external monitor: the nearest
      // display is that one, even though the laptop is listed first.
      const saved = Rect.fromLTWH(4600, 400, 1280, 720);

      final fitted = fitToDisplays(saved, const [_laptop, _external])!;

      expect(_external.contains(fitted.center), isTrue);
    });

    test('a window larger than the display it lands on is shrunk to fit', () {
      const small = Rect.fromLTWH(0, 0, 1024, 768);
      const saved = Rect.fromLTWH(3000, 3000, 2400, 1300);

      final fitted = fitToDisplays(saved, const [small])!;

      expect(fitted.width, lessThanOrEqualTo(small.width));
      expect(fitted.height, lessThanOrEqualTo(small.height));
      expect(small.contains(fitted.topLeft), isTrue);
    });

    test('no display information means do not restore a position', () {
      // Better to centre on the default than to guess.
      expect(fitToDisplays(const Rect.fromLTWH(0, 0, 1280, 720), const []),
          isNull);
    });
  });

  group('WindowGeometry.fromJson', () {
    test('round-trips', () {
      const g = WindowGeometry(
        bounds: Rect.fromLTWH(12, 34, 1280, 720),
        maximized: true,
      );

      final back = WindowGeometry.fromJson(g.toJson())!;

      expect(back.bounds, g.bounds);
      expect(back.maximized, isTrue);
    });

    test('rejects a record that would restore an ungrabbable sliver', () {
      // A half-written or hand-edited file must not strand the user with a
      // window too small to resize.
      expect(WindowGeometry.fromJson({'x': 0, 'y': 0, 'w': 40, 'h': 20}),
          isNull);
    });

    test('rejects incomplete, non-finite and non-map input', () {
      expect(WindowGeometry.fromJson({'x': 0, 'y': 0, 'w': 1280}), isNull);
      expect(
          WindowGeometry.fromJson(
              {'x': double.nan, 'y': 0, 'w': 1280, 'h': 720}),
          isNull);
      expect(
          WindowGeometry.fromJson(
              {'x': double.infinity, 'y': 0, 'w': 1280, 'h': 720}),
          isNull);
      expect(WindowGeometry.fromJson('nonsense'), isNull);
      expect(WindowGeometry.fromJson(null), isNull);
    });

    test('a missing maximized flag reads as not maximized', () {
      final g =
          WindowGeometry.fromJson({'x': 0, 'y': 0, 'w': 1280, 'h': 720})!;

      expect(g.maximized, isFalse);
    });
  });
}
