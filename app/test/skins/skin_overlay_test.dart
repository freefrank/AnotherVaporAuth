import 'dart:convert';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/skins/skin_engine.dart';
import 'package:ava/src/skins/skin_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a fixed spec instead of loading a bundled JSON pack, and lets a
/// test swap it mid-flight to exercise the spec-change recheck.
class _StubSpecController extends SkinSpecController {
  _StubSpecController(this.initial);
  final SkinSpec? initial;

  @override
  SkinSpec? build() => initial;

  void set(SkinSpec? spec) => state = spec;
}

SkinSpec _spec({required bool recDot}) => SkinSpec.parse(jsonEncode({
      'schema': 1,
      'id': 'test',
      'overlay': {
        'layers': [
          {'type': 'brackets'},
          {
            'type': 'labels',
            'items': [
              {'text': 'AVA//NET', 'anchor': 'tl', 'dx': 10.0, 'dy': 10.0},
            ],
          },
          if (recDot) {'type': 'rec_dot'},
        ],
      },
    }))!;

Widget _host(_StubSpecController controller) => ProviderScope(
      overrides: [skinSpecProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        home: const Scaffold(body: SkinOverlay()),
      ),
    );

void main() {
  testWidgets('static HUD spec (no rec_dot) never starts the blink ticker',
      (tester) async {
    final controller = _StubSpecController(_spec(recDot: false));
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    // No repeating AnimationController → nothing keeps scheduling frames.
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('rec_dot spec runs the blink ticker', (tester) async {
    final controller = _StubSpecController(_spec(recDot: true));
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('ticker follows spec swaps in both directions', (tester) async {
    final controller = _StubSpecController(_spec(recDot: false));
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);

    controller.set(_spec(recDot: true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    controller.set(_spec(recDot: false));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
