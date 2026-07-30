import 'package:ava/src/app/screen_corners.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('ava/display');

/// Answers `bottomCornerRadius` with the next value in [replies], repeating the
/// last one once exhausted, and counts the calls.
class _FakePlatform {
  final List<int> replies;
  int calls = 0;
  _FakePlatform(this.replies);

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'bottomCornerRadius') return null;
      final i = calls < replies.length ? calls : replies.length - 1;
      calls++;
      return replies[i];
    });
  }
}

/// Pumps [ScreenCornersScope] as if on Android and returns the radius it
/// published, in logical pixels.
///
/// Each round pumps past the retry interval, which both delivers the pending
/// channel reply and fires the retry timer armed by the previous round.
Future<double> _radius(WidgetTester tester, {int rounds = 12}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  var seen = 0.0;
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: ScreenCornersScope(
        child: Builder(builder: (context) {
          seen = ScreenCorners.bottomOf(context);
          return const SizedBox();
        }),
      ),
    ),
  );
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  // Must be cleared inside the test body — the framework checks for leaked
  // foundation debug vars before tearDown runs.
  debugDefaultTargetPlatformOverride = null;
  return seen;
}

void main() {
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));

  testWidgets('retries while the platform says the insets are not ready',
      (tester) async {
    // -1 means "decor view not attached to the window yet". Dart's first query
    // runs during the first build, so this is the normal startup sequence —
    // the previous version read it as 0, cached it, and never asked again,
    // which is why nothing was inset on a real phone.
    final platform = _FakePlatform([-1, -1, 120]);
    platform.install(tester);

    expect(await _radius(tester), 40); // 120px ÷ dpr 3
    expect(platform.calls, greaterThanOrEqualTo(3));
  });

  testWidgets('a real 0 is taken at face value and not retried',
      (tester) async {
    // A display with square corners must not cost a retry storm.
    final platform = _FakePlatform([0]);
    platform.install(tester);

    expect(await _radius(tester), 0);
    expect(platform.calls, 1);
  });

  testWidgets('gives up after a bounded number of retries', (tester) async {
    // A device that never attaches insets must not spin post-frame callbacks
    // for the life of the process.
    final platform = _FakePlatform([-1]);
    platform.install(tester);

    await _radius(tester, rounds: 40);

    expect(platform.calls, lessThanOrEqualTo(10));
  });

  testWidgets('no handler on the channel degrades to a square screen',
      (tester) async {
    // Desktop, pre-31 Android, and every widget test that doesn't install the
    // platform: publish 0 rather than throw MissingPluginException at a screen
    // the user is looking at.
    expect(await _radius(tester), 0);
  });
}
