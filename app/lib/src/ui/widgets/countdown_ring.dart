import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Circular TOTP countdown ring with the centred seconds number. The arc sweeps
/// down over the 30s window (1s linear steps) and shifts colour through
/// accent → warn → bad as time runs out, per the design spec.
class CountdownRing extends StatelessWidget {
  final int remaining; // seconds left in the window (1..30)
  final double size;
  final double stroke;
  const CountdownRing({
    super.key,
    required this.remaining,
    this.size = 74,
    this.stroke = 6,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final color = t.ringColor(remaining);
    final fraction = (remaining.clamp(0, 30)) / 30.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            // Animate sweep changes over 1s linear, matching the design.
            tween: Tween(begin: fraction, end: fraction),
            duration: const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (context, value, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                fraction: value,
                color: color,
                track: t.line,
                stroke: stroke,
                glow: t.glow,
              ),
            ),
          ),
          Text(
            '$remaining',
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: size * 0.28,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double stroke;
  final bool glow;
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (glow) {
      arcPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
