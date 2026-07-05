import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AVA neon palette, pixel-scene edition.
abstract final class Fx {
  static const bg = Color(0xFF05080F);
  static const panel = Color(0xFF0A1020);
  static const line = Color(0xFF1A2740);
  static const cyan = Color(0xFF00E5FF);
  static const magenta = Color(0xFFFF2BD6);
  static const green = Color(0xFF39FF88);
  static const dim = Color(0xFF6C7A96);
  static const font = 'FusionPixel';

  static TextStyle text(double size,
          {Color color = Colors.white, FontWeight? weight}) =>
      TextStyle(
          fontFamily: font,
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.2);
}

/// Full-window backdrop: faint grid, CRT scanlines and a slow moving
/// brighter band.
class ScanlinePainter extends CustomPainter {
  ScanlinePainter(this.t);
  final double t; // 0..1 loop

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Fx.cyan.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final scan = Paint()..color = Colors.white.withValues(alpha: 0.022);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    // Moving band.
    final bandY = t * (size.height + 120) - 60;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, size.width, 60),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.045),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, bandY, size.width, 60)),
    );
  }

  @override
  bool shouldRepaint(ScanlinePainter old) => old.t != t;
}

/// 1px neon frame with a cheap inward glow, drawn over everything.
class FramePainter extends CustomPainter {
  FramePainter(this.glow01);
  final double glow01; // breathing 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final a = 0.5 + glow01 * 0.5;
    for (final (w, alpha) in [(7.0, 0.05), (4.0, 0.10), (1.0, 0.9)]) {
      canvas.drawRect(
          r.deflate(w / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = Fx.cyan.withValues(alpha: alpha * a));
    }
  }

  @override
  bool shouldRepaint(FramePainter old) => old.glow01 != glow01;
}

/// Chromatic-aberration title with an occasional glitch burst.
class GlitchTitle extends StatelessWidget {
  const GlitchTitle(this.text, {super.key, required this.t, this.size = 46});
  final String text;
  final double t; // 0..1 loop
  final double size;

  @override
  Widget build(BuildContext context) {
    final burst = t > 0.94; // short glitch window each loop
    final k = burst ? 2.5 : 1.0;
    final style = Fx.text(size, weight: FontWeight.w700);
    return Stack(children: [
      Transform.translate(
          offset: Offset(-1.4 * k, 0),
          child: Text(text,
              style: style.copyWith(
                  color: Fx.magenta.withValues(alpha: 0.85)))),
      Transform.translate(
          offset: Offset(1.4 * k, burst ? 1.0 : 0),
          child: Text(text,
              style:
                  style.copyWith(color: Fx.cyan.withValues(alpha: 0.85)))),
      Text(text,
          style: style.copyWith(color: Colors.white.withValues(alpha: 0.92))),
    ]);
  }
}

class BlinkCursor extends StatelessWidget {
  const BlinkCursor({super.key, required this.t, this.size = 46});
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: (t * 2) % 1 < 0.5 ? 1 : 0,
        child: Text('_', style: Fx.text(size, color: Fx.cyan)),
      );
}

/// Chunky segmented progress bar, cells sweep cyan → magenta.
class SegmentBar extends StatelessWidget {
  const SegmentBar(this.progress, {super.key});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Fx.panel, border: Border.all(color: Fx.line, width: 2)),
      child: LayoutBuilder(builder: (context, c) {
        const cell = 9.0, gap = 3.0;
        final n = math.max(1, (c.maxWidth + gap) ~/ (cell + gap));
        final filled = (progress.clamp(0, 1) * n).round();
        return Row(children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              child: i < filled
                  ? Container(
                      decoration: BoxDecoration(
                      color: Color.lerp(Fx.cyan, Fx.magenta, i / n),
                      boxShadow: i == filled - 1
                          ? [
                              BoxShadow(
                                  color: Fx.magenta.withValues(alpha: 0.7),
                                  blurRadius: 8)
                            ]
                          : null,
                    ))
                  : Container(color: Fx.line.withValues(alpha: 0.35)),
            ),
          ],
        ]);
      }),
    );
  }
}

/// Bordered pixel button: hover inverts to a solid neon block.
class PixelButton extends StatefulWidget {
  const PixelButton(this.label,
      {super.key, required this.onTap, this.color = Fx.cyan});
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : Fx.dim;
    final on = _hover && enabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: on ? c : Colors.transparent,
            border: Border.all(color: c, width: 2),
            boxShadow: on
                ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 14)]
                : null,
          ),
          child: Text('[ ${widget.label} ]',
              style: Fx.text(14,
                  color: on ? Fx.bg : c, weight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Classic cracktro greetz marquee.
class Marquee extends StatelessWidget {
  const Marquee(this.text, {super.key, required this.t});
  final String text;
  final double t; // 0..1 loop

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _MarqueePainter(text, t),
        size: const Size(double.infinity, 20),
      ),
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter(this.text, this.t);
  final String text;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: Fx.text(12, color: Fx.dim)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width;
    final x = -t * w;
    tp.paint(canvas, Offset(x, (size.height - tp.height) / 2));
    tp.paint(canvas, Offset(x + w, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_MarqueePainter old) => old.t != t || old.text != text;
}
