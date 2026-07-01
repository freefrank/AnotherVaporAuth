import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Subtle CRT scanline overlay from the design spec. Neon variant scrolls the
/// lines slowly (`scanMove`); pixel variant is static. Non-interactive.
class ScanlineOverlay extends StatefulWidget {
  final Widget child;
  const ScanlineOverlay({super.key, required this.child});

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    // Respect the OS "reduce motion" setting: freeze the scanline scroll.
    final reduce = MediaQuery.disableAnimationsOf(context);
    final animate = t.scanAnimated && !reduce;
    if (animate) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.stop();
    }
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _ScanPainter(
                  color: t.scanColor,
                  offset: animate ? _c.value * 3 : 0,
                  gap: t.isPixel ? 4 : 3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanPainter extends CustomPainter {
  final Color color;
  final double offset;
  final double gap;
  _ScanPainter({required this.color, required this.offset, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = -gap + offset; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.offset != offset || old.color != color;
}
