import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kColorBackground = Color(0xFF16130B);
const kColorSurface = Color(0xFF231F17);
const kColorSurfaceHigh = Color(0xFF2D2A21);
const kColorSurfaceHighest = Color(0xFF38342B);
const kColorPrimary = Color(0xFFF2CA50);
const kColorPrimaryDim = Color(0xFFE9C349);
const kColorOnPrimary = Color(0xFF3C2F00);
const kColorOnSurface = Color(0xFFEAE1D4);
const kColorOnSurfaceVariant = Color(0xFFD0C5AF);
const kColorOutline = Color(0xFF99907C);
const kColorOutlineVariant = Color(0xFF4D4635);
const kColorAmberBorder = Color(0x4DD4AF37);
const kColorAmberGlow = Color(0x1AD4AF37);
const kColorAppBarBackground = Color(0xFF0A0905);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kColorBackground,
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: kColorPrimary,
      onPrimary: kColorOnPrimary,
      surface: kColorSurface,
      onSurface: kColorOnSurface,
      surfaceContainerHigh: kColorSurfaceHigh,
      surfaceContainerHighest: kColorSurfaceHighest,
      outline: kColorOutline,
      outlineVariant: kColorOutlineVariant,
    ),
    textTheme: GoogleFonts.workSansTextTheme(ThemeData.dark().textTheme)
        .copyWith(
          displayLarge: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
          headlineMedium: GoogleFonts.newsreader(
            color: kColorOnSurface,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
          headlineSmall: GoogleFonts.newsreader(
            color: kColorOnSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: GoogleFonts.spaceGrotesk(
            color: kColorOnSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: kColorAppBarBackground,
      foregroundColor: kColorOnSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.newsreader(
        color: kColorPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        letterSpacing: 3,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kColorPrimary,
      foregroundColor: kColorOnPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 6,
    ),
  );
}
