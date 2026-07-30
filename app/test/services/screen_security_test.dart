import 'package:ava/src/services/screen_security.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ava/screen_security');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void handleWith(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() {
    calls.clear();
    // The host running these tests is Linux, where `supported` is false and
    // apply() would return before ever reaching the channel — every
    // assertion below would then pass without exercising anything.
    ScreenSecurity.debugSupportedOverride = true;
  });

  tearDown(() {
    ScreenSecurity.debugSupportedOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sends setSecure with the enabled flag', () async {
    handleWith((_) async => null);

    await ScreenSecurity.apply(true);
    await ScreenSecurity.apply(false);

    expect(calls.map((c) => c.method), ['setSecure', 'setSecure']);
    expect(calls[0].arguments, {'enabled': true});
    expect(calls[1].arguments, {'enabled': false});
  });

  test('does not touch the channel on an unsupported platform', () async {
    ScreenSecurity.debugSupportedOverride = false;
    handleWith((_) async => null);

    await ScreenSecurity.apply(true);

    expect(calls, isEmpty);
  });

  test('swallows a platform error — a dead flag must not break the toggle',
      () async {
    handleWith((_) async => throw PlatformException(code: 'boom'));

    await expectLater(ScreenSecurity.apply(true), completes);
    expect(calls, hasLength(1));
  });

  test('swallows a missing handler', () async {
    // No mock handler registered at all: the framework raises
    // MissingPluginException, which is exactly what a stale engine or a
    // platform without the channel looks like.
    messenger.setMockMethodCallHandler(channel, null);

    await expectLater(ScreenSecurity.apply(true), completes);
  });
}
