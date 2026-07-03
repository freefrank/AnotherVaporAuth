import 'dart:convert';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/debug_log.dart';

/// Data-driven skin effects (schema v1).
///
/// A skin's visual effects are described as JSON and rendered by the engine in
/// `skin_engine.dart`. The vocabulary is a small set of layer types (glyph
/// rain, grids, glows, sweeps, starfields, brackets, ticks, labels…) whose
/// parameters fully reproduce the built-in Neon and Pixel looks — see
/// `assets/skins/*.json`. Unknown layer types are skipped, so newer packs
/// degrade gracefully on older engines. Colors are either `#AARRGGBB` /
/// `#RRGGBB` literals or `$token` references (`$bg`, `$accent`, `$accent2`,
/// `$text`, `$muted`, `$line`, `$panel`, `$good`, `$bad`, `$warn`) resolved
/// against the active [AvaTokens] at paint time.
///
/// The full schema (including the future `tokens` / `fonts` sections used by
/// downloadable packs) is documented in `docs/skin-schema.md`.
class SkinSpec {
  static const int supportedSchema = 1;

  final int schema;
  final String id;
  final List<LayerSpec> ambient; // behind the content, edge-to-edge
  final TopFadeSpec? topFade; // status-bar protection for the ambient
  final List<LayerSpec> overlay; // above the content, inside the safe area
  final ScanlineSpec? scanline; // CRT overlay wrapped around screen bodies
  final PullSpec? pull; // pull-to-refresh wash

  const SkinSpec({
    required this.schema,
    required this.id,
    required this.ambient,
    required this.topFade,
    required this.overlay,
    required this.scanline,
    required this.pull,
  });

  static SkinSpec? parse(String jsonText) {
    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      final schema = (map['schema'] as num?)?.toInt() ?? 0;
      if (schema > supportedSchema) {
        dlog('skin: schema $schema newer than engine, ignoring pack');
        return null;
      }
      final ambient = map['ambient'] as Map<String, dynamic>? ?? const {};
      final overlay = map['overlay'] as Map<String, dynamic>? ?? const {};
      return SkinSpec(
        schema: schema,
        id: map['id'] as String? ?? 'unknown',
        ambient: _layers(ambient['layers']),
        topFade: TopFadeSpec.fromJson(
            ambient['topFade'] as Map<String, dynamic>?),
        overlay: _layers(overlay['layers']),
        scanline:
            ScanlineSpec.fromJson(map['scanline'] as Map<String, dynamic>?),
        pull: PullSpec.fromJson(map['pull'] as Map<String, dynamic>?),
      );
    } catch (e) {
      dlog('skin: failed to parse spec: $e');
      return null;
    }
  }

  static List<LayerSpec> _layers(dynamic list) {
    if (list is! List) return const [];
    final out = <LayerSpec>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final layer = LayerSpec.fromJson(e);
      if (layer != null) {
        out.add(layer);
      } else {
        dlog('skin: skipping unknown layer type "${e['type']}"');
      }
    }
    return out;
  }
}

/// A color that is either a literal or a `$token` reference, resolved lazily
/// so the same spec adapts if token values change.
class SkinColor {
  final Color? literal;
  final String? token;
  const SkinColor.value(this.literal) : token = null;
  const SkinColor.ref(this.token) : literal = null;

  static const _fallback = Color(0xFFFF00FF); // loud magenta: spec bug beacon

  factory SkinColor.parse(dynamic v, {Color orElse = _fallback}) {
    if (v is String && v.startsWith(r'$')) return SkinColor.ref(v.substring(1));
    if (v is String && v.startsWith('#')) {
      final hex = v.substring(1);
      final argb = hex.length == 6 ? 'FF$hex' : hex;
      final parsed = int.tryParse(argb, radix: 16);
      if (parsed != null) return SkinColor.value(Color(parsed));
    }
    return SkinColor.value(orElse);
  }

  Color resolve(AvaTokens t) {
    if (literal != null) return literal!;
    return switch (token) {
      'bg' => t.bg,
      'panel' => t.panel,
      'panel2' => t.panel2,
      'chrome' => t.chrome,
      'line' => t.line,
      'text' => t.text,
      'muted' => t.muted,
      'accent' => t.accent,
      'accent2' => t.accent2,
      'good' => t.good,
      'bad' => t.bad,
      'warn' => t.warn,
      _ => _fallback,
    };
  }
}

double _d(Map<String, dynamic> m, String k, double orElse) =>
    (m[k] as num?)?.toDouble() ?? orElse;
int _i(Map<String, dynamic> m, String k, int orElse) =>
    (m[k] as num?)?.toInt() ?? orElse;
bool _b(Map<String, dynamic> m, String k, bool orElse) =>
    m[k] as bool? ?? orElse;
String _s(Map<String, dynamic> m, String k, String orElse) =>
    m[k] as String? ?? orElse;

/// Base class for effect layers. `fromJson` returns null for unknown types.
sealed class LayerSpec {
  const LayerSpec();

  static LayerSpec? fromJson(Map<String, dynamic> m) =>
      switch (m['type'] as String?) {
        'glow_corner' => GlowCornerSpec.fromJson(m),
        'grid' => GridSpec.fromJson(m),
        'glyph_rain' => GlyphRainSpec.fromJson(m),
        'sweep' => SweepSpec.fromJson(m),
        'band_step' => BandStepSpec.fromJson(m),
        'starfield' => StarfieldSpec.fromJson(m),
        'brackets' => BracketsSpec.fromJson(m),
        'ticks' => TicksSpec.fromJson(m),
        'labels' => LabelsSpec.fromJson(m),
        'rec_dot' => RecDotSpec.fromJson(m),
        _ => null,
      };
}

/// Breathing radial glow anchored to a corner/edge (neon red/blue corners).
class GlowCornerSpec extends LayerSpec {
  final Alignment align;
  final SkinColor color;
  final double alphaMin, alphaMax;
  final double radius;
  final bool invertPhase; // breathe out of phase with the master loop
  const GlowCornerSpec(this.align, this.color, this.alphaMin, this.alphaMax,
      this.radius, this.invertPhase);
  factory GlowCornerSpec.fromJson(Map<String, dynamic> m) => GlowCornerSpec(
        Alignment(_d(m, 'alignX', -1), _d(m, 'alignY', -1)),
        SkinColor.parse(m['color']),
        _d(m, 'alphaMin', 0.05),
        _d(m, 'alphaMax', 0.12),
        _d(m, 'radius', 1.1),
        _b(m, 'invertPhase', false),
      );
}

/// Regular line/pixel grid, optionally drifting with the master phase.
class GridSpec extends LayerSpec {
  final double gap;
  final SkinColor color;
  final double alpha;
  final double stroke;
  final bool drift;
  final bool chunky; // 1px rects (pixel look) instead of hairlines
  const GridSpec(
      this.gap, this.color, this.alpha, this.stroke, this.drift, this.chunky);
  factory GridSpec.fromJson(Map<String, dynamic> m) => GridSpec(
        _d(m, 'gap', 34),
        SkinColor.parse(m['color']),
        _d(m, 'alpha', 0.045),
        _d(m, 'stroke', 1),
        _b(m, 'drift', true),
        _b(m, 'chunky', false),
      );
}

/// Matrix-style falling glyph columns.
class GlyphRainSpec extends LayerSpec {
  final String glyphs;
  final double cell;
  final double fontSize;
  final String fontFamily;
  final SkinColor headColor;
  final double headAlpha;
  final List<SkinColor> palette; // alternated across columns
  final double alphaMin, alphaMax;
  final double speedMin, speedMax;
  final int lenMin, lenMax;
  final double flicker; // per-tick probability of mutating a trail glyph
  const GlyphRainSpec(
      this.glyphs,
      this.cell,
      this.fontSize,
      this.fontFamily,
      this.headColor,
      this.headAlpha,
      this.palette,
      this.alphaMin,
      this.alphaMax,
      this.speedMin,
      this.speedMax,
      this.lenMin,
      this.lenMax,
      this.flicker);
  factory GlyphRainSpec.fromJson(Map<String, dynamic> m) => GlyphRainSpec(
        _s(m, 'glyphs', '01'),
        _d(m, 'cell', 16),
        _d(m, 'fontSize', 13),
        _s(m, 'fontFamily', 'JetBrainsMono'),
        SkinColor.parse(m['headColor'], orElse: const Color(0xFFFFFFFF)),
        _d(m, 'headAlpha', 0.85),
        [
          for (final c in (m['palette'] as List? ?? const ['#00FF00']))
            SkinColor.parse(c)
        ],
        _d(m, 'alphaMin', 0.06),
        _d(m, 'alphaMax', 0.48),
        _d(m, 'speedMin', 60),
        _d(m, 'speedMax', 230),
        _i(m, 'lenMin', 6),
        _i(m, 'lenMax', 22),
        _d(m, 'flicker', 0.18),
      );
}

/// Soft sweeping line with a trailing gradient band (neon radar).
class SweepSpec extends LayerSpec {
  final SkinColor color;
  final double band;
  final double bandAlpha;
  final double lineWidth;
  final double lineAlpha;
  final double blur;
  const SweepSpec(this.color, this.band, this.bandAlpha, this.lineWidth,
      this.lineAlpha, this.blur);
  factory SweepSpec.fromJson(Map<String, dynamic> m) => SweepSpec(
        SkinColor.parse(m['color']),
        _d(m, 'band', 90),
        _d(m, 'bandAlpha', 0.10),
        _d(m, 'lineWidth', 2),
        _d(m, 'lineAlpha', 0.45),
        _d(m, 'blur', 8),
      );
}

/// Hard-stepped bright band sweeping down (pixel scanline band).
class BandStepSpec extends LayerSpec {
  final SkinColor color;
  final double px; // pixel unit for snapping / band thickness
  final double speedFactor;
  final double alpha;
  final double echoAlpha;
  const BandStepSpec(
      this.color, this.px, this.speedFactor, this.alpha, this.echoAlpha);
  factory BandStepSpec.fromJson(Map<String, dynamic> m) => BandStepSpec(
        SkinColor.parse(m['color'], orElse: const Color(0xFFFF8A3D)),
        _d(m, 'px', 4),
        _d(m, 'speedFactor', 1.3),
        _d(m, 'alpha', 0.14),
        _d(m, 'echoAlpha', 0.08),
      );
}

/// Multi-layer drifting starfield of hard squares (pixel stars).
class StarfieldSpec extends LayerSpec {
  final SkinColor color;
  final SkinColor color2;
  final double px; // snap unit
  final List<({int count, double speed, double size, double alpha})> bands;
  const StarfieldSpec(this.color, this.color2, this.px, this.bands);
  factory StarfieldSpec.fromJson(Map<String, dynamic> m) => StarfieldSpec(
        SkinColor.parse(m['color'], orElse: const Color(0xFFFF8A3D)),
        SkinColor.parse(m['color2'], orElse: const Color(0xFF43C8FF)),
        _d(m, 'px', 4),
        [
          for (final b in (m['bands'] as List? ?? const []))
            if (b is Map<String, dynamic>)
              (
                count: _i(b, 'count', 30),
                speed: _d(b, 'speed', 1),
                size: _d(b, 'size', 4),
                alpha: _d(b, 'alpha', 0.6),
              )
        ],
      );
}

/// Corner brackets: thin rounded lines (neon HUD) or chunky rects (pixel).
class BracketsSpec extends LayerSpec {
  final String style; // 'line' | 'rect'
  final double margin;
  final double arm;
  final double thickness;
  final SkinColor color;
  final double alpha;
  final bool safeTop; // push the top pair below the status bar (ambient only)
  const BracketsSpec(this.style, this.margin, this.arm, this.thickness,
      this.color, this.alpha, this.safeTop);
  factory BracketsSpec.fromJson(Map<String, dynamic> m) => BracketsSpec(
        _s(m, 'style', 'line'),
        _d(m, 'margin', 8),
        _d(m, 'arm', 22),
        _d(m, 'thickness', 1.6),
        SkinColor.parse(m['color']),
        _d(m, 'alpha', 0.55),
        _b(m, 'safeTop', false),
      );
}

/// Edge tick marks along the top and bottom (neon HUD).
class TicksSpec extends LayerSpec {
  final double gap;
  final int longEvery;
  final double len;
  final double lenLong;
  final SkinColor color;
  final double alpha;
  final double inset; // distance from the corner brackets
  const TicksSpec(this.gap, this.longEvery, this.len, this.lenLong, this.color,
      this.alpha, this.inset);
  factory TicksSpec.fromJson(Map<String, dynamic> m) => TicksSpec(
        _d(m, 'gap', 16),
        _i(m, 'longEvery', 4),
        _d(m, 'len', 3),
        _d(m, 'lenLong', 6),
        SkinColor.parse(m['color']),
        _d(m, 'alpha', 0.25),
        _d(m, 'inset', 44),
      );
}

/// Small monospace labels anchored to corners (neon HUD "AVA//NET").
class LabelsSpec extends LayerSpec {
  final List<({String text, String anchor, double dx, double dy})> items;
  final SkinColor color;
  final double fontSize;
  final String fontFamily;
  final double letterSpacing;
  const LabelsSpec(
      this.items, this.color, this.fontSize, this.fontFamily, this.letterSpacing);
  factory LabelsSpec.fromJson(Map<String, dynamic> m) => LabelsSpec(
        [
          for (final e in (m['items'] as List? ?? const []))
            if (e is Map<String, dynamic>)
              (
                text: _s(e, 'text', ''),
                anchor: _s(e, 'anchor', 'tl'),
                dx: _d(e, 'dx', 0),
                dy: _d(e, 'dy', 0),
              )
        ],
        SkinColor.parse(m['color']),
        _d(m, 'fontSize', 9),
        _s(m, 'fontFamily', 'JetBrainsMono'),
        _d(m, 'letterSpacing', 1.5),
      );
}

/// Blinking REC-style dot + label (neon HUD).
class RecDotSpec extends LayerSpec {
  final String text;
  final SkinColor color;
  final String anchor;
  final double dx, dy;
  const RecDotSpec(this.text, this.color, this.anchor, this.dx, this.dy);
  factory RecDotSpec.fromJson(Map<String, dynamic> m) => RecDotSpec(
        _s(m, 'text', 'REC'),
        SkinColor.parse(m['color'], orElse: const Color(0xFFFF1B6B)),
        _s(m, 'anchor', 'tr'),
        _d(m, 'dx', -16),
        _d(m, 'dy', 30),
      );
}

/// Fade the ambient back to the backdrop under the status bar.
class TopFadeSpec {
  final String style; // 'gradient' | 'steps'
  final SkinColor color;
  const TopFadeSpec(this.style, this.color);
  static TopFadeSpec? fromJson(Map<String, dynamic>? m) => m == null
      ? null
      : TopFadeSpec(_s(m, 'style', 'gradient'), SkinColor.parse(m['color']));
}

/// CRT scanline overlay wrapped around screen bodies.
class ScanlineSpec {
  final double gap;
  final SkinColor color;
  final bool animated;
  const ScanlineSpec(this.gap, this.color, this.animated);
  static ScanlineSpec? fromJson(Map<String, dynamic>? m) => m == null
      ? null
      : ScanlineSpec(
          _d(m, 'gap', 3), SkinColor.parse(m['color']), _b(m, 'animated', false));
}

/// Pull-to-refresh wash. The two styles are engine-native; colors are data.
class PullSpec {
  final String style; // 'neon' | 'pixel'
  final SkinColor colorA; // neon: top-left wash / pixel: fill+bar color
  final SkinColor colorB; // neon: bottom-right wash
  final SkinColor lineA; // neon: sweep line pair
  final SkinColor lineB;
  const PullSpec(this.style, this.colorA, this.colorB, this.lineA, this.lineB);
  static PullSpec? fromJson(Map<String, dynamic>? m) => m == null
      ? null
      : PullSpec(
          _s(m, 'style', 'neon'),
          SkinColor.parse(m['colorA'], orElse: const Color(0xFF18E0FF)),
          SkinColor.parse(m['colorB'], orElse: const Color(0xFFFF1B6B)),
          SkinColor.parse(m['lineA'], orElse: const Color(0xFF00FFFF)),
          SkinColor.parse(m['lineB'], orElse: const Color(0xFFFF2BD6)),
        );
}
