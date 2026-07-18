import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/route_observer.dart';
import '../app/theme.dart';
import 'skin_spec.dart';

final _rnd = math.Random();

// Glyph cache keyed by char/color/font so each frame re-paints prebuilt
// TextPainters instead of re-laying-out text.
final Map<String, TextPainter> _glyphCache = {};
TextPainter _glyph(String ch, Color color, String family, double size) {
  final key = '$ch|${color.toARGB32()}|$family|$size';
  return _glyphCache.putIfAbsent(key, () {
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1.0,
          fontFamily: family,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  });
}

class _RainColumn {
  double y; // px position of the head (bottom-most glyph)
  double speed; // px/s
  int len; // trail length
  List<String> chars;
  _RainColumn(this.y, this.speed, this.len, this.chars);

  factory _RainColumn.spawn(GlyphRainSpec s, double height,
      {bool anywhere = false}) {
    final len = s.lenMin + _rnd.nextInt(math.max(1, s.lenMax - s.lenMin));
    String g() => s.glyphs[_rnd.nextInt(s.glyphs.length)];
    return _RainColumn(
      anywhere ? _rnd.nextDouble() * height : -_rnd.nextDouble() * height,
      s.speedMin + _rnd.nextDouble() * (s.speedMax - s.speedMin),
      len,
      List.generate(len + 1, (_) => g()),
    );
  }
}

/// Per-glyph_rain-layer mutable animation state.
class _RainState {
  Size size = Size.zero;
  List<_RainColumn> cols = const [];

  void ensure(GlyphRainSpec s, Size newSize) {
    if (newSize == size && cols.isNotEmpty) return;
    size = newSize;
    final n = (newSize.width / s.cell).ceil() + 1;
    cols = List.generate(
        n, (_) => _RainColumn.spawn(s, newSize.height, anywhere: true));
  }

  void tick(GlyphRainSpec s, double dt) {
    final h = size.height;
    if (h <= 0) return;
    String g() => s.glyphs[_rnd.nextInt(s.glyphs.length)];
    for (final c in cols) {
      c.y += c.speed * dt;
      if (_rnd.nextDouble() < s.flicker) {
        c.chars[_rnd.nextInt(c.chars.length)] = g();
      }
      if (c.y - (c.len + 1) * s.cell > h) {
        final fresh = _RainColumn.spawn(s, h);
        c
          ..y = fresh.y
          ..speed = fresh.speed
          ..len = fresh.len
          ..chars = fresh.chars;
      }
    }
  }
}

/// Always-on, non-interactive ambience painted behind the content, rendered
/// from the active skin's `ambient` layers. Renders nothing when no skin (or
/// no spec) is active — the plain themes.
class SkinAmbient extends ConsumerStatefulWidget {
  const SkinAmbient({super.key});

  @override
  ConsumerState<SkinAmbient> createState() => _SkinAmbientState();
}

class _SkinAmbientState extends ConsumerState<SkinAmbient>
    with SingleTickerProviderStateMixin, RouteAware {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  double _phase = 0; // 0..1 master loop (6s), shared by all layers
  final Map<int, _RainState> _rain = {};
  // Bumped every tick so the painter repaints without rebuilding the widget.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  bool _covered = false;
  bool _reduce = false;
  SkinSpec? _spec;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pause while covered by a full-screen page (route may be null in tests;
    // transparent overlays — dialogs, sheets, menus — must not pause us).
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _covered = true;
    _updateRunning();
  }

  @override
  void didPopNext() {
    _covered = false;
    _last = Duration.zero; // elapsed restarts from zero on start()
    _updateRunning();
  }

  void _updateRunning() {
    final shouldRun = !_covered &&
        !_reduce &&
        _spec != null &&
        _spec!.ambient.isNotEmpty &&
        mounted;
    if (shouldRun && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _phase = (elapsed.inMilliseconds % 6000) / 6000;
    final spec = _spec;
    if (spec != null) {
      for (var i = 0; i < spec.ambient.length; i++) {
        final layer = spec.ambient[i];
        if (layer is GlyphRainSpec) _rain[i]?.tick(layer, dt);
      }
    }
    _frame.value++; // repaint only — no widget rebuild
  }

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(skinSpecProvider);
    if (!identical(spec, _spec)) {
      _spec = spec;
      _rain.clear();
    }
    _reduce = MediaQuery.disableAnimationsOf(context);
    _updateRunning();
    if (spec == null || spec.ambient.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    final topInset = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      // Own layer so the per-frame repaint doesn't force the whole screen
      // subtree to repaint with it.
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (_, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            for (var i = 0; i < spec.ambient.length; i++) {
              final layer = spec.ambient[i];
              if (layer is GlyphRainSpec) {
                (_rain[i] ??= _RainState()).ensure(layer, size);
              }
            }
            return CustomPaint(
              size: Size.infinite,
              painter: _AmbientPainter(
                spec: spec,
                rain: _rain,
                phaseOf: () => _phase,
                tokens: tokens,
                topInset: topInset,
                repaint: _frame,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final SkinSpec spec;
  final Map<int, _RainState> rain;
  final double Function() phaseOf;
  final AvaTokens tokens;
  final double topInset;
  _AmbientPainter({
    required this.spec,
    required this.rain,
    required this.phaseOf,
    required this.tokens,
    required this.topInset,
    required Listenable repaint,
  }) : super(repaint: repaint);

  double _snap(double v, double px) => (v / px).floorToDouble() * px;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = phaseOf();
    for (var i = 0; i < spec.ambient.length; i++) {
      final layer = spec.ambient[i];
      switch (layer) {
        case GlowCornerSpec s:
          _glow(canvas, size, s, phase);
        case GridSpec s:
          _grid(canvas, size, s, phase);
        case GlyphRainSpec s:
          _rainLayer(canvas, size, s, rain[i]);
        case SweepSpec s:
          _sweep(canvas, size, s, phase);
        case BandStepSpec s:
          _bandStep(canvas, size, s, phase);
        case StarfieldSpec s:
          _starfield(canvas, size, s, phase);
        case BracketsSpec s:
          _brackets(canvas, size, s, safeTopInset: s.safeTop ? topInset : 0);
        case TicksSpec _:
        case LabelsSpec _:
        case RecDotSpec _:
          break; // overlay-only layer types
      }
    }
    _topFade(canvas, size);
  }

  void _glow(Canvas canvas, Size size, GlowCornerSpec s, double phase) {
    final rect = Offset.zero & size;
    var breath = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    if (s.invertPhase) breath = 1 - breath;
    final color = s.color.resolve(tokens);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: s.align,
          radius: s.radius,
          colors: [
            color.withValues(
                alpha: s.alphaMin + (s.alphaMax - s.alphaMin) * breath),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );
  }

  void _grid(Canvas canvas, Size size, GridSpec s, double phase) {
    final w = size.width, h = size.height;
    final drift = s.drift ? (phase * s.gap) % s.gap : 0.0;
    final paint = Paint()
      ..color = s.color.resolve(tokens).withValues(alpha: s.alpha)
      ..strokeWidth = s.stroke;
    if (s.chunky) {
      for (var x = -s.gap + drift; x < w; x += s.gap) {
        canvas.drawRect(Rect.fromLTWH(x, 0, s.stroke, h), paint);
      }
      for (var y = -s.gap + drift; y < h; y += s.gap) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, s.stroke), paint);
      }
    } else {
      for (var x = -s.gap + drift; x < w; x += s.gap) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
      }
      for (var y = -s.gap + drift; y < h; y += s.gap) {
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      }
    }
  }

  void _rainLayer(Canvas canvas, Size size, GlyphRainSpec s, _RainState? st) {
    if (st == null) return;
    final h = size.height;
    final head = s.headColor.resolve(tokens).withValues(alpha: s.headAlpha);
    final palette = [for (final c in s.palette) c.resolve(tokens)];
    if (palette.isEmpty) return;
    for (var i = 0; i < st.cols.length; i++) {
      final x = i * s.cell + 2;
      final c = st.cols[i];
      for (var k = 0; k <= c.len; k++) {
        final gy = c.y - k * s.cell;
        if (gy < -s.cell || gy > h) continue;
        final Color color;
        if (k == 0) {
          color = head;
        } else {
          final f = 1 - k / c.len; // brighter near the head
          final base = palette[i % palette.length];
          color = base.withValues(
              alpha: s.alphaMin + (s.alphaMax - s.alphaMin) * f);
        }
        _glyph(c.chars[k], color, s.fontFamily, s.fontSize)
            .paint(canvas, Offset(x, gy));
      }
    }
  }

  void _sweep(Canvas canvas, Size size, SweepSpec s, double phase) {
    final w = size.width, h = size.height;
    final color = s.color.resolve(tokens);
    final sy = phase * (h + 120) - 60;
    final band = Rect.fromLTWH(0, sy - s.band, w, s.band);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: s.bandAlpha)
          ],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, sy),
      Offset(w, sy),
      Paint()
        ..color = color.withValues(alpha: s.lineAlpha)
        ..strokeWidth = s.lineWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur),
    );
  }

  void _bandStep(Canvas canvas, Size size, BandStepSpec s, double phase) {
    final w = size.width, h = size.height;
    final color = s.color.resolve(tokens);
    final bandY = _snap(((phase * s.speedFactor) % 1.0) * (h + 60) - 30, s.px);
    canvas.drawRect(Rect.fromLTWH(0, bandY, w, s.px),
        Paint()..color = color.withValues(alpha: s.alpha));
    canvas.drawRect(Rect.fromLTWH(0, bandY + s.px * 1.5, w, 2),
        Paint()..color = color.withValues(alpha: s.echoAlpha));
  }

  void _starfield(Canvas canvas, Size size, StarfieldSpec s, double phase) {
    final w = size.width, h = size.height;
    final c1 = s.color.resolve(tokens);
    final c2 = s.color2.resolve(tokens);
    var seed = 0;
    for (final band in s.bands) {
      seed++;
      final drift = _snap(phase * h * band.speed, s.px);
      for (var i = 0; i < band.count; i++) {
        // Deterministic pseudo-random positions (no runtime RNG).
        final bx = ((i * 73 + seed * 37 + 11) % 100) / 100 * w;
        final by = ((i * 137 + seed * 91 + 29) % 100) / 100 * h;
        final y = (by + drift) % h;
        final twinkle = ((i + (phase * 12).floor()) % 5) == 0;
        final c = (i % 4 == 0) ? c2 : c1;
        final a = twinkle ? band.alpha : band.alpha * 0.55;
        canvas.drawRect(
          Rect.fromLTWH(_snap(bx, s.px), _snap(y, s.px), band.size, band.size),
          Paint()..color = c.withValues(alpha: a),
        );
      }
    }
  }

  void _brackets(Canvas canvas, Size size, BracketsSpec s,
      {double safeTopInset = 0}) {
    paintBrackets(canvas, size, s, tokens, safeTopInset: safeTopInset);
  }

  void _topFade(Canvas canvas, Size size) {
    final f = spec.topFade;
    if (f == null || topInset <= 0) return;
    final w = size.width;
    final color = f.color.resolve(tokens);
    if (f.style == 'steps') {
      const px = 4.0;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, topInset),
          Paint()..color = color.withValues(alpha: 0.85));
      // Stepped dissolve edge instead of a smooth gradient — stays 8-bit.
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(0, topInset + i * px, w, px),
          Paint()..color = color.withValues(alpha: 0.6 - 0.2 * i),
        );
      }
    } else {
      final fade = Rect.fromLTWH(0, 0, w, topInset + 20);
      canvas.drawRect(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.55, 1],
          ).createShader(fade),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => // frames come via `repaint`
      old.spec != spec || old.tokens != tokens || old.topInset != topInset;
}

/// Shared bracket painting (ambient chunky rects / overlay thin lines).
void paintBrackets(Canvas canvas, Size size, BracketsSpec s, AvaTokens tokens,
    {double safeTopInset = 0}) {
  final w = size.width, h = size.height;
  final color = s.color.resolve(tokens).withValues(alpha: s.alpha);
  final m = s.margin, arm = s.arm, th = s.thickness;
  if (s.style == 'rect') {
    final fp = Paint()..color = color;
    final tm = m + safeTopInset;
    canvas.drawRect(Rect.fromLTWH(m, tm, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(m, tm, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - arm, tm, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - th, tm, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(m, h - m - th, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(m, h - m - arm, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - arm, h - m - th, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - th, h - m - arm, th, arm), fp);
  } else {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = th
      ..strokeCap = StrokeCap.round;
    void corner(Offset o, int sx, int sy) {
      canvas.drawLine(o, o.translate(arm * sx, 0), stroke);
      canvas.drawLine(o, o.translate(0, arm * sy), stroke);
    }

    corner(Offset(m, m + safeTopInset), 1, 1);
    corner(Offset(w - m, m + safeTopInset), -1, 1);
    corner(Offset(m, h - m), 1, -1);
    corner(Offset(w - m, h - m), -1, -1);
  }
}

/// Thin HUD painted on top of the content, inside the safe area, from the
/// active skin's `overlay` layers. Renders nothing when the list is empty.
class SkinOverlay extends ConsumerStatefulWidget {
  const SkinOverlay({super.key});

  @override
  ConsumerState<SkinOverlay> createState() => _SkinOverlayState();
}

class _SkinOverlayState extends ConsumerState<SkinOverlay>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _covered = false;
  bool _hasRecDot = false;
  SkinSpec? _spec;
  // Label painters live on the state so they survive frames; rebuilt when the
  // spec changes (same idea as the file-level _glyphCache, but per spec).
  final Map<String, TextPainter> _labelCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _covered = true;
    _updateRunning();
  }

  @override
  void didPopNext() {
    _covered = false;
    _updateRunning();
  }

  // The 1.4s tick only drives the blinking REC dot. Specs without one keep
  // the controller parked, so a static HUD paints once and never repaints.
  void _updateRunning() {
    final shouldRun = !_covered && _hasRecDot && mounted;
    if (shouldRun && !_c.isAnimating) {
      _c.repeat();
    } else if (!shouldRun && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(skinSpecProvider);
    if (!identical(spec, _spec)) {
      _spec = spec;
      _hasRecDot = spec?.overlay.any((l) => l is RecDotSpec) ?? false;
      _labelCache.clear();
    }
    _updateRunning();
    if (spec == null || spec.overlay.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    // Keep the HUD chrome (brackets, ticks, labels) inside the safe area so
    // it doesn't collide with the status bar or gesture bar.
    return IgnorePointer(
      child: RepaintBoundary(
        child: Padding(
          padding: MediaQuery.paddingOf(context),
          child: CustomPaint(
            size: Size.infinite,
            painter: _OverlayPainter(
              spec: spec,
              tokens: tokens,
              t: _c,
              labelCache: _labelCache,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final SkinSpec spec;
  final AvaTokens tokens;
  final Animation<double> t;
  // Owned by _SkinOverlayState so laid-out labels survive across frames
  // (the HUD text is a small fixed set per spec).
  final Map<String, TextPainter> labelCache;
  _OverlayPainter({
    required this.spec,
    required this.tokens,
    required this.t,
    required this.labelCache,
  }) : super(repaint: t);

  void _label(Canvas canvas, String text, Offset at, Color color,
      LabelsSpec style,
      {bool right = false}) {
    final key = '$text|${color.toARGB32()}|${style.fontSize}'
        '|${style.fontFamily}|${style.letterSpacing}';
    final tp = labelCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: style.fontSize,
            fontFamily: style.fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: style.letterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    tp.paint(canvas, right ? at.translate(-tp.width, 0) : at);
  }

  static const _labelDefaults =
      LabelsSpec([], SkinColor.value(Color(0xFF18E0FF)), 9, 'JetBrainsMono', 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final layer in spec.overlay) {
      switch (layer) {
        case BracketsSpec s:
          paintBrackets(canvas, size, s, tokens);
        case TicksSpec s:
          final paint = Paint()
            ..color = s.color.resolve(tokens).withValues(alpha: s.alpha)
            ..strokeWidth = 1;
          for (var x = s.inset; x < w - s.inset; x += s.gap) {
            final long = ((x / s.gap).round() % s.longEvery == 0);
            final len = long ? s.lenLong : s.len;
            canvas.drawLine(Offset(x, 8), Offset(x, 8 + len), paint);
            canvas.drawLine(Offset(x, h - 8), Offset(x, h - 8 - len), paint);
          }
        case LabelsSpec s:
          final color = s.color.resolve(tokens);
          for (final item in s.items) {
            final right = item.anchor == 'tr' || item.anchor == 'br';
            final x = right ? w + item.dx : item.dx;
            final y = item.anchor == 'bl' || item.anchor == 'br'
                ? h + item.dy
                : item.dy;
            _label(canvas, item.text, Offset(x, y), color, s, right: right);
          }
        case RecDotSpec s:
          final on = t.value % 1.0 < 0.5;
          if (on) {
            final color = s.color.resolve(tokens);
            final right = s.anchor == 'tr' || s.anchor == 'br';
            final dot = Offset(right ? w + s.dx : s.dx,
                s.anchor == 'bl' || s.anchor == 'br' ? h + s.dy : s.dy);
            canvas.drawCircle(
                dot,
                3,
                Paint()
                  ..color = color
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
            _label(canvas, s.text, dot.translate(-8, -5), color,
                _labelDefaults,
                right: true);
          }
        default:
          break; // ambient-only layer types
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.spec != spec || old.tokens != tokens;
}
