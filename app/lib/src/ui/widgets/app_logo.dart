import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// The AVA app logo. Switches between the Neon and Pixel artwork to match the
/// active theme (the OS launcher icon can't change at runtime, but the in-app
/// logo does).
class AppLogo extends ConsumerWidget {
  final double size;
  const AppLogo({super.key, this.size = 84});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(themeVariantProvider);
    final asset = variant == AvaThemeVariant.pixel
        ? 'assets/icon/icon_pixel.png'
        : 'assets/icon/icon_neon.png';
    final radius = variant == AvaThemeVariant.pixel ? size * 0.12 : size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality:
            variant == AvaThemeVariant.pixel ? FilterQuality.none : FilterQuality.medium,
      ),
    );
  }
}
