import 'package:ava/src/app/responsive.dart';
import 'package:ava/src/app/screen_corners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders [builder] under a viewport of [width] with the given system
/// [padding], and hands back the BuildContext so the extension can be called
/// with a real MediaQuery in scope.
Future<void> _withContext(
  WidgetTester tester, {
  required double width,
  required EdgeInsets padding,
  double cornerRadius = 0,
  required void Function(BuildContext context) check,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
          size: Size(width, 800), padding: padding, viewPadding: padding),
      child: ScreenCorners(
        bottom: cornerRadius,
        child: Builder(builder: (context) {
          check(context);
          return const SizedBox();
        }),
      ),
    ),
  );
}

void main() {
  group('rSafeInsets', () {
    testWidgets('adds the system insets to the scaled design padding',
        (tester) async {
      // 390dp is the design reference width, so scale == 1.0 and the design
      // value passes through unchanged — isolating the system-inset maths.
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(top: 48, bottom: 24),
        check: (context) {
          expect(context.rSafeInsets(all: 16),
              const EdgeInsets.only(left: 16, top: 64, right: 16, bottom: 40));
        },
      );
    });

    testWidgets('system insets are NOT scaled — they are OS measurements',
        (tester) async {
      // 195dp halves the scale to the 0.85 clamp: the design's 16 shrinks to
      // 13.6, but the 24dp gesture handle stays 24dp. Scaling it would put
      // content under the handle on small phones, which is the whole bug.
      await _withContext(
        tester,
        width: 195,
        padding: const EdgeInsets.only(bottom: 24),
        check: (context) {
          final insets = context.rSafeInsets(all: 16);
          expect(insets.bottom, closeTo(16 * 0.85 + 24, 0.001));
          expect(insets.left, closeTo(16 * 0.85, 0.001));
        },
      );
    });

    testWidgets('degrades to rInsets when there are no system insets',
        (tester) async {
      // Desktop, and any screen whose Scaffold already stripped the top inset
      // for an AppBar: the helper must be a no-op, not a source of extra gaps.
      await _withContext(
        tester,
        width: 390,
        padding: EdgeInsets.zero,
        check: (context) {
          expect(context.rSafeInsets(all: 16), context.rInsets(all: 16));
        },
      );
    });

    testWidgets('covers left/right too, for landscape cutouts', (tester) async {
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(left: 44, right: 12),
        check: (context) {
          final insets = context.rSafeInsets(h: 16);
          expect(insets.left, 60);
          expect(insets.right, 28);
          expect(insets.top, 0);
        },
      );
    });
  });

  group('rounded corners', () {
    testWidgets('a corner deeper than the system inset wins the bottom',
        (tester) async {
      // 40dp arc vs a 24dp gesture pill: content parked at 24dp is still
      // clipped near the left/right edges, so the arc decides.
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(bottom: 24),
        cornerRadius: 40,
        check: (context) =>
            expect(context.rSafeInsets(all: 16).bottom, 16 + 40),
      );
    });

    testWidgets('they are max()ed, never summed', (tester) async {
      // Summing would park content at 16+24+40 = 80 and leave a dead strip on
      // every screen; the pill's height already lies inside the arc's sweep.
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(bottom: 24),
        cornerRadius: 40,
        check: (context) =>
            expect(context.rSafeInsets(all: 16).bottom, isNot(16 + 24 + 40)),
      );
    });

    testWidgets('a corner inside the system inset changes nothing',
        (tester) async {
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(bottom: 48),
        cornerRadius: 20,
        check: (context) {
          expect(context.rSafeInsets(all: 16).bottom, 16 + 48);
          expect(context.cornerOvershoot, 0);
        },
      );
    });

    testWidgets('cornerOvershoot is only the part the system inset misses',
        (tester) async {
      // What a Scaffold-positioned FAB needs: endFloat already cleared the
      // 24dp pill, so adding the full 40 would float it 24dp too high.
      await _withContext(
        tester,
        width: 390,
        padding: const EdgeInsets.only(bottom: 24),
        cornerRadius: 40,
        check: (context) => expect(context.cornerOvershoot, 16),
      );
    });

    testWidgets('no ScreenCorners above it reads as a square screen',
        (tester) async {
      // Every widget test, desktop, and Android below 31 land here — the
      // helper must degrade to the plain system inset, not throw.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(390, 800), padding: EdgeInsets.only(bottom: 24)),
          child: Builder(builder: (context) {
            expect(context.rSafeInsets(all: 16).bottom, 40);
            expect(context.cornerOvershoot, 0);
            return const SizedBox();
          }),
        ),
      );
    });
  });
}
