import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Always-on, non-interactive retro backdrop for the PIXEL theme: a chunky pixel
/// grid, a two-layer scrolling starfield that drifts DOWN in hard pixel steps, a
/// bright scanline band sweeping down, and hard-edged corner brackets.
/// Frame-stepped (nothing glides) to match the 8-bit aesthetic. Low-alpha so
/// foreground text stays readable.
class PixelAmbient extends StatefulWidget {
  const PixelAmbient({super.key});

  @override
  State<PixelAmbient> createState() => _PixelAmbientState();
}

class _PixelAmbientState extends State<PixelAmbient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _PixelPainter(
            grid: t.line,
            star: t.accent,
            star2: t.accent2,
            frame: t.text,
            phase: reduce ? 0 : _c.value,
          ),
        ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  final Color grid;
  final Color star;
  final Color star2;
  final Color frame;
  final double phase; // 0..1 loop
  _PixelPainter({
    required this.grid,
    required this.star,
    required this.star2,
    required this.frame,
    required this.phase,
  });

  static const double _cell = 18; // grid cell
  static const double _px = 4; // "pixel" unit

  // Snap a value down to the pixel grid so motion steps, not glides.
  double _snap(double v) => (v / _px).floorToDouble() * _px;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Faint chunky pixel grid.
    final gp = Paint()..color = grid.withValues(alpha: 0.10);
    for (var x = 0.0; x < w; x += _cell) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, h), gp);
    }
    for (var y = 0.0; y < h; y += _cell) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, 1), gp);
    }

    // Two-layer scrolling starfield drifting DOWN in pixel steps.
    _stars(canvas, w, h, count: 34, speed: 1.0, size: _px, alpha: 0.55, seed: 1);
    _stars(canvas, w, h, count: 22, speed: 0.5, size: _px + 2, alpha: 0.8, seed: 2);

    // Bright scanline band sweeping down (chunky, stepped).
    final bandY = _snap(((phase * 1.3) % 1.0) * (h + 60) - 30);
    canvas.drawRect(Rect.fromLTWH(0, bandY, w, _px),
        Paint()..color = star.withValues(alpha: 0.14));
    canvas.drawRect(Rect.fromLTWH(0, bandY + _px * 1.5, w, 2),
        Paint()..color = star.withValues(alpha: 0.08));

    // Hard-edged chunky corner brackets.
    final fp = Paint()..color = frame.withValues(alpha: 0.28);
    const m = 6.0, arm = 26.0, th = 4.0;
    canvas.drawRect(const Rect.fromLTWH(m, m, arm, th), fp);
    canvas.drawRect(const Rect.fromLTWH(m, m, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - arm, m, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - th, m, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(m, h - m - th, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(m, h - m - arm, th, arm), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - arm, h - m - th, arm, th), fp);
    canvas.drawRect(Rect.fromLTWH(w - m - th, h - m - arm, th, arm), fp);
  }

  void _stars(Canvas canvas, double w, double h,
      {required int count,
      required double speed,
      required double size,
      required double alpha,
      required int seed}) {
    final drift = _snap(phase * h * speed);
    for (var i = 0; i < count; i++) {
      // Deterministic pseudo-random positions (no runtime RNG).
      final bx = ((i * 73 + seed * 37 + 11) % 100) / 100 * w;
      final by = ((i * 137 + seed * 91 + 29) % 100) / 100 * h;
      final y = (by + drift) % h;
      final twinkle = ((i + (phase * 12).floor()) % 5) == 0;
      final c = (i % 4 == 0) ? star2 : star;
      final a = twinkle ? alpha : alpha * 0.55;
      canvas.drawRect(
        Rect.fromLTWH(_snap(bx), _snap(y), size, size),
        Paint()..color = c.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.phase != phase;
}
