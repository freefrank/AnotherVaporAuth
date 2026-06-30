import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A horizontal step indicator (design screens 04/05). [current] is the active
/// step index; earlier steps render as done (✓), the active step pulses, later
/// steps are muted.
class Stepper3 extends StatefulWidget {
  final List<String> labels;
  final int current;
  const Stepper3({super.key, required this.labels, required this.current});

  @override
  State<Stepper3> createState() => _Stepper3State();
}

class _Stepper3State extends State<Stepper3>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final children = <Widget>[];
    for (var i = 0; i < widget.labels.length; i++) {
      final done = i < widget.current;
      final active = i == widget.current;
      children.add(_badge(t, i, done, active));
      children.add(const SizedBox(width: 7));
      children.add(Flexible(
        child: Text(
          widget.labels[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: (done || active) ? t.text : t.muted,
            fontSize: 12,
          ),
        ),
      ));
      if (i < widget.labels.length - 1) {
        children.add(Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: i < widget.current ? t.accent : t.line,
          ),
        ));
      }
    }
    return Row(children: children);
  }

  Widget _badge(SdaTokens t, int i, bool done, bool active) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = active ? t.glowShadow(blur: 4 + _c.value * 10) : const <BoxShadow>[];
        final bg = done ? t.good : (active ? t.accent : t.panel2);
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(t.radiusSm),
            border: (done || active) ? null : Border.all(color: t.borderColor),
            boxShadow: glow,
          ),
          child: done
              ? const Icon(Icons.check, size: 13, color: Color(0xFF06060F))
              : Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: active ? const Color(0xFF06060F) : t.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        );
      },
    );
  }
}

/// A slowly spinning accent arc ring (spinSlow 1.5s) wrapping [child].
class SpinnerRing extends StatefulWidget {
  final double size;
  final Widget child;
  const SpinnerRing({super.key, this.size = 96, required this.child});

  @override
  State<SpinnerRing> createState() => _SpinnerRingState();
}

class _SpinnerRingState extends State<SpinnerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _ArcPainter(color: t.accent, track: t.line, glow: t.glow),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final Color track;
  final bool glow;
  _ArcPainter({required this.color, required this.track, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.width - 4) / 2;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (glow) arc.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 0, 1.6, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
