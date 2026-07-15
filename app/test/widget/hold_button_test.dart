import 'package:ava/src/ui/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hapticTimesMs', () {
    test('intervals strictly shrink (accelerating feel) and fit duration', () {
      final times = HoldToConfirmButton.hapticTimesMs(900);
      expect(times.first, 0);
      expect(times.last, lessThan(900));
      for (var i = 2; i < times.length; i++) {
        final prev = times[i - 1] - times[i - 2];
        final cur = times[i] - times[i - 1];
        expect(cur, lessThan(prev),
            reason: 'interval $i must be shorter than interval ${i - 1}');
      }
      expect(times.length, greaterThanOrEqualTo(5));
    });
  });

  group('widget', () {
    testWidgets('completes only after full hold', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      // 短按不触发。
      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();
      expect(fired, 0);
      // 按满 300ms 触发一次。
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('accept')));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('early release cancels and resets', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('accept')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up(); // 提前松手
      await tester.pumpAndSettle();
      expect(fired, 0);
    });

    testWidgets('holdEnabled=false degrades to a plain tap', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            holdEnabled: false,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('round variant renders icon and holds like pill', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton.round(
            icon: Icons.check,
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.check)));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
    });
  });
}
