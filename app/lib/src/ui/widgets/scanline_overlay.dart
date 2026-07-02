import 'package:flutter/material.dart';

import '../../app/route_observer.dart';
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
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  bool _animate = true;
  bool _covered = false; // a pushed route is on top of this screen

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
    _updateRunning();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _c.dispose();
    super.dispose();
  }

  // Scroll only when the theme wants it and no pushed route covers us.
  void _updateRunning() {
    if (_animate && !_covered) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    // Respect the OS "reduce motion" setting: freeze the scanline scroll.
    final reduce = MediaQuery.disableAnimationsOf(context);
    _animate = t.scanAnimated && !reduce;
    _updateRunning();
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            // Own layer so the per-frame scanline repaint doesn't force the
            // whole screen subtree to repaint with it.
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ScanPainter(
                  color: t.scanColor,
                  anim: _c,
                  animate: _animate,
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
  final Animation<double> anim; // repaint driver, read in paint()
  final bool animate;
  final double gap;
  _ScanPainter({
    required this.color,
    required this.anim,
    required this.animate,
    required this.gap,
  }) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final offset = animate ? anim.value * 3 : 0.0;
    final paint = Paint()..color = color;
    for (double y = -gap + offset; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => // frame repaints come from `anim`
      old.color != color || old.gap != gap || old.animate != animate;
}
