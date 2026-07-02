import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/route_observer.dart';

/// Glyph pool for the digital rain — ASCII only so it renders on every device.
const _glyphs = '0123456789ABCDEFGHJKLMNPRSTUVWXYZ#%&*+<>/=:';
const _cell = 16.0; // column width / glyph row height
final _rnd = math.Random();

// Glyph cache keyed by "char|argb" so each frame just re-paints prebuilt
// TextPainters instead of re-laying-out text.
final Map<String, TextPainter> _glyphCache = {};
TextPainter _glyph(String ch, Color color) {
  final key = '$ch|${color.toARGB32()}';
  return _glyphCache.putIfAbsent(key, () {
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          color: color,
          fontSize: 13,
          height: 1.0,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  });
}

String _randomGlyph() => _glyphs[_rnd.nextInt(_glyphs.length)];

class _RainColumn {
  double y; // px position of the head (bottom-most glyph)
  double speed; // px/s
  int len; // trail length
  List<String> chars;
  _RainColumn(this.y, this.speed, this.len, this.chars);

  factory _RainColumn.spawn(double height, {bool anywhere = false}) {
    final len = 6 + _rnd.nextInt(16);
    return _RainColumn(
      anywhere ? _rnd.nextDouble() * height : -_rnd.nextDouble() * height,
      60 + _rnd.nextDouble() * 170,
      len,
      List.generate(len + 1, (_) => _randomGlyph()),
    );
  }
}

/// Always-on, non-interactive cyberpunk ambience painted behind the content:
/// drifting neon grid, breathing red/blue corner glows, a periodic radar sweep
/// and Matrix-style digital rain. Low-alpha so foreground text stays readable.
class CyberAmbient extends StatefulWidget {
  const CyberAmbient({super.key});

  @override
  State<CyberAmbient> createState() => _CyberAmbientState();
}

/// Mutable animation state owned by the State: the ticker advances it every
/// frame and the painter reads it by reference on every repaint.
class _RainModel {
  double phase = 0; // 0..1 slow loop for grid/glow/sweep
  List<_RainColumn> cols = const [];
}

class _CyberAmbientState extends State<CyberAmbient>
    with SingleTickerProviderStateMixin, RouteAware {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  final _RainModel _model = _RainModel();
  // Bumped every tick so the painter repaints without rebuilding the widget.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

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
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void didPopNext() {
    if (!_ticker.isActive) {
      _last = Duration.zero; // elapsed restarts from zero on start()
      _ticker.start();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _ensureColumns(Size size) {
    if (size == _size && _model.cols.isNotEmpty) return;
    _size = size;
    final n = (size.width / _cell).ceil() + 1;
    _model.cols = List.generate(
        n, (_) => _RainColumn.spawn(size.height, anywhere: true));
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _model.phase = (elapsed.inMilliseconds % 6000) / 6000;
    final h = _size.height;
    if (h > 0) {
      for (final c in _model.cols) {
        c.y += c.speed * dt;
        // Flicker a random glyph in the trail.
        if (_rnd.nextDouble() < 0.18) {
          c.chars[_rnd.nextInt(c.chars.length)] = _randomGlyph();
        }
        if (c.y - (c.len + 1) * _cell > h) {
          final fresh = _RainColumn.spawn(h);
          c
            ..y = fresh.y
            ..speed = fresh.speed
            ..len = fresh.len
            ..chars = fresh.chars;
        }
      }
    }
    _frame.value++; // repaint only — no widget rebuild
  }

  @override
  Widget build(BuildContext context) {
    // Fade the ambience out under the status bar so rain glyphs and glows
    // don't fight the clock/battery icons (the backdrop stays edge-to-edge).
    final topFade = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (_, c) {
            _ensureColumns(Size(c.maxWidth, c.maxHeight));
            return CustomPaint(
              size: Size.infinite,
              painter: _CyberPainter(
                model: _model,
                repaint: _frame,
                topFade: topFade,
                fadeColor: const Color(0xFF06060F),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CyberPainter extends CustomPainter {
  final _RainModel model;
  final double topFade; // status-bar height to fade out under
  final Color fadeColor;
  _CyberPainter({
    required this.model,
    required Listenable repaint,
    required this.topFade,
    required this.fadeColor,
  }) : super(repaint: repaint);

  static const _red = Color(0xFFFF1B6B);
  static const _blue = Color(0xFF18E0FF);
  static const _cyan = Color(0xFF00FFFF);
  static const _green = Color(0xFF39FF8B);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = model.phase;
    final cols = model.cols;
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final breath = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);

    // Breathing corner glows (red top-left, blue bottom-right, out of phase).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1, -1),
          radius: 1.1,
          colors: [
            _red.withValues(alpha: 0.05 + 0.07 * breath),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1, 1),
          radius: 1.1,
          colors: [
            _blue.withValues(alpha: 0.05 + 0.07 * (1 - breath)),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );

    // Slowly drifting neon grid.
    const gap = 34.0;
    final drift = (phase * gap) % gap;
    final grid = Paint()
      ..color = _cyan.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = -gap + drift; x < w; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = -gap + drift; y < h; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Digital rain.
    for (var i = 0; i < cols.length; i++) {
      final x = i * _cell + 2;
      final c = cols[i];
      for (var k = 0; k <= c.len; k++) {
        final gy = c.y - k * _cell;
        if (gy < -_cell || gy > h) continue;
        final ch = c.chars[k];
        final Color color;
        if (k == 0) {
          color = Colors.white.withValues(alpha: 0.85);
        } else {
          final f = 1 - k / c.len; // brighter near the head
          final base = i.isEven ? _green : _cyan;
          color = base.withValues(alpha: 0.06 + 0.42 * f);
        }
        _glyph(ch, color).paint(canvas, Offset(x, gy));
      }
    }

    // Radar sweep line with a soft trailing band.
    final sy = phase * (h + 120) - 60;
    final band = Rect.fromLTWH(0, sy - 90, w, 90);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cyan.withValues(alpha: 0), _cyan.withValues(alpha: 0.10)],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, sy),
      Offset(w, sy),
      Paint()
        ..color = _cyan.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Status-bar protection: fade the ambience back to the backdrop colour
    // across the top inset so system icons stay clean.
    if (topFade > 0) {
      final fade = Rect.fromLTWH(0, 0, w, topFade + 20);
      canvas.drawRect(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fadeColor, fadeColor.withValues(alpha: 0)],
            stops: const [0.55, 1],
          ).createShader(fade),
      );
    }
  }

  @override
  bool shouldRepaint(_CyberPainter old) => // frames come via `repaint`
      old.topFade != topFade || old.fadeColor != fadeColor;
}

/// A thin neon HUD frame on top of everything: angled corner brackets, edge
/// ticks, a couple of labels and a blinking "REC" dot.
class CyberHud extends StatefulWidget {
  const CyberHud({super.key});

  @override
  State<CyberHud> createState() => _CyberHudState();
}

class _CyberHudState extends State<CyberHud>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final _HudPainter _painter = _HudPainter(_c);

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
    if (_c.isAnimating) _c.stop();
  }

  @override
  void didPopNext() {
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the HUD chrome (brackets, ticks, labels) inside the safe area so
    // it doesn't collide with the status bar or gesture bar.
    return IgnorePointer(
      child: RepaintBoundary(
        child: Padding(
          padding: MediaQuery.paddingOf(context),
          child: CustomPaint(size: Size.infinite, painter: _painter),
        ),
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  final Animation<double> t;
  _HudPainter(this.t) : super(repaint: t);

  static const _cyan = Color(0xFF18E0FF);
  static const _red = Color(0xFFFF1B6B);

  void _label(Canvas canvas, String text, Offset at, Color color,
      {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, right ? at.translate(-tp.width, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const m = 8.0; // margin
    const arm = 22.0; // corner bracket arm length
    final stroke = Paint()
      ..color = _cyan.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    void corner(Offset o, int sx, int sy) {
      canvas.drawLine(o, o.translate(arm * sx, 0), stroke);
      canvas.drawLine(o, o.translate(0, arm * sy), stroke);
    }

    corner(Offset(m, m), 1, 1);
    corner(Offset(w - m, m), -1, 1);
    corner(Offset(m, h - m), 1, -1);
    corner(Offset(w - m, h - m), -1, -1);

    // Edge tick marks along the top and bottom.
    final tick = Paint()
      ..color = _cyan.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = m + arm + 14; x < w - m - arm - 14; x += 16) {
      final long = ((x / 16).round() % 4 == 0);
      canvas.drawLine(Offset(x, m), Offset(x, m + (long ? 6 : 3)), tick);
      canvas.drawLine(
          Offset(x, h - m), Offset(x, h - m - (long ? 6 : 3)), tick);
    }

    // Labels.
    _label(canvas, 'AVA//NET', Offset(m + 6, m + arm + 4), _cyan);
    _label(canvas, 'SECURE', Offset(w - m - 6, h - m - arm - 14), _cyan,
        right: true);

    // Blinking REC dot, top-right.
    final on = t.value % 1.0 < 0.5;
    if (on) {
      final dot = Offset(w - m - 16, m + arm + 8);
      canvas.drawCircle(
          dot,
          3,
          Paint()
            ..color = _red
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      _label(canvas, 'REC', dot.translate(-8, -5), _red, right: true);
    }
  }

  @override
  bool shouldRepaint(_HudPainter old) => false; // driven by the controller
}
