import 'dart:io';

import 'package:ava/src/app/theme.dart';
import 'package:ava/src/skins/skin_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bundled skin packs', () {
    test('neon.json reproduces the neon look', () {
      final spec =
          SkinSpec.parse(File('assets/skins/neon.json').readAsStringSync())!;
      expect(spec.schema, 1);
      expect(spec.id, 'neon');
      expect(spec.ambient.map((l) => l.runtimeType).toList(), [
        GlowCornerSpec,
        GlowCornerSpec,
        GridSpec,
        GlyphRainSpec,
        SweepSpec,
      ]);
      expect(spec.overlay.map((l) => l.runtimeType).toList(), [
        BracketsSpec,
        TicksSpec,
        LabelsSpec,
        RecDotSpec,
      ]);
      final rain = spec.ambient[3] as GlyphRainSpec;
      expect(rain.cell, 16);
      expect(rain.glyphs, contains('#%&*+<>/=:'));
      expect(rain.palette, hasLength(2));
      expect(spec.scanline!.animated, isTrue);
      expect(spec.scanline!.gap, 3);
      expect(spec.pull!.style, 'neon');
      expect(spec.topFade!.style, 'gradient');
    });

    test('pixel.json reproduces the pixel look with token refs', () {
      final spec =
          SkinSpec.parse(File('assets/skins/pixel.json').readAsStringSync())!;
      expect(spec.id, 'pixel');
      expect(spec.ambient.map((l) => l.runtimeType).toList(), [
        GridSpec,
        StarfieldSpec,
        BandStepSpec,
        BracketsSpec,
      ]);
      expect(spec.overlay, isEmpty);
      final pixelTokens = AvaTokens.of(AvaThemeVariant.pixel);
      final stars = spec.ambient[1] as StarfieldSpec;
      expect(stars.color.resolve(pixelTokens), pixelTokens.accent);
      expect(stars.bands, hasLength(2));
      expect(stars.bands.first.count, 34);
      final brackets = spec.ambient[3] as BracketsSpec;
      expect(brackets.style, 'rect');
      expect(brackets.safeTop, isTrue);
      expect(spec.scanline!.animated, isFalse);
      expect(spec.pull!.style, 'pixel');
      expect(spec.topFade!.style, 'steps');
    });
  });

  group('robustness', () {
    test('unknown layer types are skipped, known ones survive', () {
      final spec = SkinSpec.parse('''
        {"schema": 1, "id": "x", "ambient": {"layers": [
          {"type": "wormhole", "answer": 42},
          {"type": "grid", "gap": 10}
        ]}}
      ''')!;
      expect(spec.ambient, hasLength(1));
      expect(spec.ambient.single, isA<GridSpec>());
    });

    test('a pack from a newer schema is rejected as a whole', () {
      expect(SkinSpec.parse('{"schema": 99, "id": "future"}'), isNull);
    });

    test('malformed JSON returns null instead of throwing', () {
      expect(SkinSpec.parse('not json at all'), isNull);
    });

    test('color parsing: literals, token refs and fallback', () {
      final t = AvaTokens.of(AvaThemeVariant.neon);
      expect(SkinColor.parse('#FF0000').resolve(t), const Color(0xFFFF0000));
      expect(SkinColor.parse('#8000FF00').resolve(t), const Color(0x8000FF00));
      expect(SkinColor.parse(r'$accent').resolve(t), t.accent);
      expect(SkinColor.parse(r'$nonsense').resolve(t), const Color(0xFFFF00FF));
      expect(SkinColor.parse(12345).resolve(t), const Color(0xFFFF00FF));
    });
  });
}
