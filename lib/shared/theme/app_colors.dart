import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

/// Theme-aware semantic colors. Read them off a [BuildContext] via
/// `context.colors.<name>`; the values flip automatically with the active
/// [ThemeMode]. The field names mirror the legacy `kColor*` consts 1:1, so a
/// call site migrates by swapping `kColorSurface` → `context.colors.surface`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color primary;
  final Color primaryDim;
  final Color onPrimary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color amberBorder;
  final Color amberGlow;
  final Color appBarBackground;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.primary,
    required this.primaryDim,
    required this.onPrimary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.amberBorder,
    required this.amberGlow,
    required this.appBarBackground,
  });

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? primary,
    Color? primaryDim,
    Color? onPrimary,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? amberBorder,
    Color? amberGlow,
    Color? appBarBackground,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      onPrimary: onPrimary ?? this.onPrimary,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      amberBorder: amberBorder ?? this.amberBorder,
      amberGlow: amberGlow ?? this.amberGlow,
      appBarBackground: appBarBackground ?? this.appBarBackground,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      amberBorder: Color.lerp(amberBorder, other.amberBorder, t)!,
      amberGlow: Color.lerp(amberGlow, other.amberGlow, t)!,
      appBarBackground: Color.lerp(
        appBarBackground,
        other.appBarBackground,
        t,
      )!,
    );
  }
}

/// Dark palette — the legacy look, sourced from the `kColor*` consts.
const AppColors kDarkColors = AppColors(
  background: kColorBackground,
  surface: kColorSurface,
  surfaceHigh: kColorSurfaceHigh,
  surfaceHighest: kColorSurfaceHighest,
  primary: kColorPrimary,
  primaryDim: kColorPrimaryDim,
  onPrimary: kColorOnPrimary,
  onSurface: kColorOnSurface,
  onSurfaceVariant: kColorOnSurfaceVariant,
  outline: kColorOutline,
  outlineVariant: kColorOutlineVariant,
  amberBorder: kColorAmberBorder,
  amberGlow: kColorAmberGlow,
  appBarBackground: kColorAppBarBackground,
);

/// Light palette — a warm "paper" counterpart. Primary is deepened to a bronze
/// gold so it stays legible both as accent text on the cream background and as a
/// fill behind white [onPrimary] text.
const AppColors kLightColors = AppColors(
  background: Color(0xFFFAF6EC),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFF1EADA),
  surfaceHighest: Color(0xFFE7DEC9),
  primary: Color(0xFF7A5E0A),
  primaryDim: Color(0xFF8A6D12),
  onPrimary: Color(0xFFFFFFFF),
  onSurface: Color(0xFF241F14),
  onSurfaceVariant: Color(0xFF5C5340),
  outline: Color(0xFF8A8069),
  outlineVariant: Color(0xFFD8CFB8),
  amberBorder: Color(0x66A07A1A),
  amberGlow: Color(0x14A07A1A),
  appBarBackground: Color(0xFFF3EDDF),
);

/// `context.colors.<name>` — the theme-aware accessor used across the app.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildDarkTheme() =>
    _buildTheme(c: kDarkColors, brightness: Brightness.dark);

ThemeData buildLightTheme() =>
    _buildTheme(c: kLightColors, brightness: Brightness.light);

ThemeData _buildTheme({required AppColors c, required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final baseText = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
  final scheme = isDark
      ? ColorScheme.dark(
          brightness: Brightness.dark,
          primary: c.primary,
          onPrimary: c.onPrimary,
          surface: c.surface,
          onSurface: c.onSurface,
          surfaceContainerHigh: c.surfaceHigh,
          surfaceContainerHighest: c.surfaceHighest,
          outline: c.outline,
          outlineVariant: c.outlineVariant,
          onSurfaceVariant: c.onSurfaceVariant,
        )
      : ColorScheme.light(
          brightness: Brightness.light,
          primary: c.primary,
          onPrimary: c.onPrimary,
          surface: c.surface,
          onSurface: c.onSurface,
          surfaceContainerHigh: c.surfaceHigh,
          surfaceContainerHighest: c.surfaceHighest,
          outline: c.outline,
          outlineVariant: c.outlineVariant,
          onSurfaceVariant: c.onSurfaceVariant,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.background,
    colorScheme: scheme,
    extensions: [c],
    textTheme: GoogleFonts.workSansTextTheme(baseText).kr.copyWith(
      displayLarge: GoogleFonts.newsreader(
        color: c.primary,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
      ).kr,
      headlineMedium: GoogleFonts.newsreader(
        color: c.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ).kr,
      headlineSmall: GoogleFonts.newsreader(
        color: c.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ).kr,
      labelSmall: GoogleFonts.spaceGrotesk(
        color: c.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ).kr,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.appBarBackground,
      foregroundColor: c.onSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.newsreader(
        color: c.primary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        letterSpacing: 3,
      ).kr,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 6,
    ),
  );
}
