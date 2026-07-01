import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Displays the Steam Guard code in the code font with the design's neon glow,
/// flipping in (perspective rotateX -90°→0° + fade, 550ms) whenever the code
/// value changes — i.e. once per 30s window.
class FlipCode extends StatelessWidget {
  final String code;
  final double fontSize;

  /// Letter spacing. Defaults to the design's relative `0.16em`
  /// (`fontSize * 0.16`) so it stays proportional when the code is scaled.
  final double? letterSpacing;
  const FlipCode({
    super.key,
    required this.code,
    this.fontSize = 44,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final style = TextStyle(
      fontFamily: DefaultTextStyle.of(context).style.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacing ?? fontSize * 0.16,
      color: t.accent,
      shadows: t.glow
          ? [Shadow(color: t.accent.withValues(alpha: 0.6), blurRadius: 22)]
          : null,
    );
    // Respect the OS "reduce motion" setting: swap the code with a plain fade.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 120 : 550),
      switchInCurve: const Cubic(0.2, 0.75, 0.25, 1),
      transitionBuilder: (child, anim) {
        if (reduce) return FadeTransition(opacity: anim, child: child);
        return AnimatedBuilder(
          animation: anim,
          builder: (context, _) {
            final v = anim.value;
            final angle = (1 - v) * (math.pi / 2); // -90°→0°
            return Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(-angle),
                child: child,
              ),
            );
          },
        );
      },
      child: Text(code, key: ValueKey(code), style: style),
    );
  }
}
