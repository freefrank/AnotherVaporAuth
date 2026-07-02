import 'package:flutter/material.dart';

/// The two visual themes from the AVA motion design spec.
enum AvaThemeVariant { neon, pixel }

/// Design tokens carried on [ThemeData] so any widget can read the current
/// theme's palette, glow, fonts and radii. Mirrors the CSS custom properties in
/// the `AVA 动效设计稿` comp (NEON cyan/magenta vs PIXEL orange/retro).
@immutable
class AvaTokens extends ThemeExtension<AvaTokens> {
  final AvaThemeVariant variant;

  final Color bg;
  final Color panel;
  final Color panel2;
  final Color chrome;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accent2;
  final Color good;
  final Color bad;
  final Color warn;

  final double radius;
  final double radiusSm;
  final double radiusLg;
  final double borderWidth;
  final Color borderColor;

  /// Code glyph size for the focused main code.
  final double codeSize;

  /// Neon themes glow; pixel theme uses a hard offset shadow instead.
  final bool glow;

  /// Background corner gradient (neon only).
  final Gradient? bgGradient;

  /// Scanline overlay color + whether it animates.
  final Color scanColor;
  final bool scanAnimated;

  const AvaTokens({
    required this.variant,
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.chrome,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.good,
    required this.bad,
    required this.warn,
    required this.radius,
    required this.radiusSm,
    required this.radiusLg,
    required this.borderWidth,
    required this.borderColor,
    required this.codeSize,
    required this.glow,
    required this.bgGradient,
    required this.scanColor,
    required this.scanAnimated,
  });

  bool get isPixel => variant == AvaThemeVariant.pixel;

  /// Ring / bar colour by seconds remaining: <=5 bad, <=10 warn, else accent.
  Color ringColor(int remaining) {
    if (remaining <= 5) return bad;
    if (remaining <= 10) return warn;
    return accent;
  }

  /// Glow shadow used around accented elements (empty in pixel theme).
  List<BoxShadow> glowShadow({double blur = 16, double opacity = 0.45}) {
    if (!glow) return const [];
    return [BoxShadow(color: accent.withValues(alpha: opacity), blurRadius: blur)];
  }

  /// Card shadow: soft neon halo vs hard pixel offset.
  List<BoxShadow> cardShadow() {
    if (isPixel) {
      return [BoxShadow(color: const Color(0xFF15111F), offset: const Offset(5, 5))];
    }
    return [
      BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 60, offset: const Offset(0, 20)),
      BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 50),
    ];
  }

  Border get border => Border.all(color: borderColor, width: borderWidth);

  // ---- token sets -------------------------------------------------------

  static const _neon = AvaTokens(
    variant: AvaThemeVariant.neon,
    bg: Color(0xFF06060F),
    panel: Color(0xA60E101E),
    panel2: Color(0xD916182C),
    chrome: Color(0xD1090A16),
    line: Color(0x3D00F0FF),
    text: Color(0xFFE9F6FF),
    muted: Color(0xFF7488AD),
    accent: Color(0xFF00F0FF),
    accent2: Color(0xFFFF2BD6),
    good: Color(0xFF36F0A0),
    bad: Color(0xFFFF476F),
    warn: Color(0xFFFFD23B),
    radius: 13,
    radiusSm: 8,
    radiusLg: 30,
    borderWidth: 1,
    borderColor: Color(0x3D00F0FF),
    codeSize: 44,
    glow: true,
    bgGradient: RadialGradient(
      center: Alignment(0.45, -1.1),
      radius: 1.4,
      colors: [Color(0x1A00F0FF), Color(0x0006060F)],
    ),
    scanColor: Color(0x0D00F0FF),
    scanAnimated: true,
  );

  static const _pixel = AvaTokens(
    variant: AvaThemeVariant.pixel,
    bg: Color(0xFF2B2547),
    panel: Color(0xFF39335C),
    panel2: Color(0xFF463D72),
    chrome: Color(0xFF221E38),
    line: Color(0xFF5A5288),
    text: Color(0xFFFBF3DF),
    muted: Color(0xFF9A90C0),
    accent: Color(0xFFFF8A3D),
    accent2: Color(0xFF43C8FF),
    good: Color(0xFF6FE07A),
    bad: Color(0xFFFF5D6C),
    warn: Color(0xFFFFD23B),
    radius: 0,
    radiusSm: 0,
    radiusLg: 4,
    borderWidth: 2,
    borderColor: Color(0xFF15111F),
    codeSize: 58,
    glow: false,
    bgGradient: null,
    scanColor: Color(0x29000000),
    scanAnimated: false,
  );

  static AvaTokens of(AvaThemeVariant v) =>
      v == AvaThemeVariant.pixel ? _pixel : _neon;

  @override
  AvaTokens copyWith() => this;

  @override
  AvaTokens lerp(ThemeExtension<AvaTokens>? other, double t) {
    if (other is! AvaTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Builds the global [ThemeData] for a variant. The dark cyberpunk base
/// cascades to every screen; widgets read [AvaTokens] for accents and motion.
ThemeData buildAvaTheme(AvaThemeVariant variant) {
  final t = AvaTokens.of(variant);

  // Bundled fonts (no runtime download). Pixel theme uses Fusion Pixel for both
  // Latin and CJK (single pixel family). Neon theme uses Latin display/code
  // fonts with Noto Sans SC as the Chinese (CJK) fallback.
  final codeFamily = t.isPixel ? 'FusionPixel' : 'JetBrainsMono';
  final displayFamily = t.isPixel ? 'FusionPixel' : 'ChakraPetch';
  final cjkFallback = t.isPixel
      ? const ['FusionPixel', 'NotoSansSC']
      : const ['NotoSansSC'];

  TextTheme displayCode(TextTheme base) => base.apply(
        fontFamily: codeFamily,
        fontFamilyFallback: cjkFallback,
        bodyColor: t.text,
        displayColor: t.text,
      );

  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: t.accent,
    secondary: t.accent2,
    surface: t.panel2,
    error: t.bad,
    onPrimary: const Color(0xFF06060F),
  );

  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  final displayFont =
      TextStyle(fontFamily: displayFamily, fontFamilyFallback: cjkFallback);

  return base.copyWith(
    colorScheme: scheme,
    // Transparent so the app-level backdrop (bg + neon gradient) shows through.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: t.bg,
    textTheme: displayCode(base.textTheme),
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.chrome,
      foregroundColor: t.text,
      elevation: 0,
      titleTextStyle: displayFont.copyWith(
        color: t.text,
        fontSize: t.isPixel ? 12 : 16,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
        borderSide: BorderSide(color: t.borderColor, width: t.borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
        borderSide: BorderSide(color: t.borderColor, width: t.borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
        borderSide: BorderSide(color: t.accent, width: t.borderWidth),
      ),
      labelStyle: TextStyle(color: t.muted),
      hintStyle: TextStyle(color: t.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: const Color(0xFF06060F),
        textStyle: displayFont.copyWith(
          fontSize: t.isPixel ? 11 : 13,
          letterSpacing: 0.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusSm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.borderColor, width: t.borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusSm),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
        side: BorderSide(color: t.borderColor, width: t.borderWidth),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.panel2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
        side: BorderSide(color: t.borderColor, width: t.borderWidth),
      ),
      titleTextStyle: displayFont.copyWith(
        color: t.text,
        fontSize: t.isPixel ? 13 : 17,
        letterSpacing: 0.4,
      ),
      contentTextStyle: TextStyle(
        color: t.text,
        fontSize: 14,
        fontFamily: codeFamily,
        fontFamilyFallback: cjkFallback,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: t.accent,
      unselectedLabelColor: t.muted,
      indicatorColor: t.accent,
      dividerColor: t.line,
      labelStyle: displayFont.copyWith(
        fontSize: t.isPixel ? 11 : 13,
        letterSpacing: 0.5,
      ),
      // Must be set explicitly: unselected tabs don't inherit labelStyle.
      unselectedLabelStyle: displayFont.copyWith(
        fontSize: t.isPixel ? 11 : 13,
        letterSpacing: 0.5,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.panel2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
        side: BorderSide(color: t.borderColor, width: t.borderWidth),
      ),
      // M3 menu items read labelTextStyle (textStyle is the M2 path).
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
        color: t.text,
        fontSize: 13.5,
        fontFamily: codeFamily,
        fontFamilyFallback: cjkFallback,
      )),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.panel2,
      contentTextStyle: TextStyle(color: t.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
        side: BorderSide(color: t.accent.withValues(alpha: 0.4)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: t.line,
    iconTheme: IconThemeData(color: t.muted),
    listTileTheme: ListTileThemeData(textColor: t.text, iconColor: t.muted),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.line,
      circularTrackColor: t.line,
    ),
  );
}
