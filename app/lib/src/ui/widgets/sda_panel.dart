import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A bordered panel/card in the design's style (neon glow halo or pixel hard
/// shadow depending on theme). Used across screens for cards and form blocks.
class SdaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emphasized; // accent border + glow
  final Color? color;
  const SdaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.emphasized = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.panel,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(
          color: emphasized ? t.accent : t.borderColor,
          width: t.borderWidth,
        ),
        boxShadow: emphasized
            ? t.glowShadow(blur: 16, opacity: 0.25)
            : (t.isPixel ? t.cardShadow() : const []),
      ),
      child: child,
    );
  }
}

/// A small type chip (e.g. Trade / Market), accent-coloured.
class SdaChip extends StatelessWidget {
  final String label;
  final Color color;
  const SdaChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }
}
