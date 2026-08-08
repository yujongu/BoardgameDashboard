import 'package:flutter/material.dart';

/// The bundled Hangul face (see `pubspec.yaml`, weights 400–700).
const kKoreanFontFamily = 'GothicA1';

const _koreanFallback = <String>[kKoreanFontFamily];

/// Adds the Korean fallback face to a style built by `google_fonts`.
///
/// Newsreader, Space Grotesk and Work Sans ship no Hangul glyphs, so without
/// this every Korean string falls through to whatever face the platform picks
/// (Apple SD Gothic Neo on iOS, Noto Sans CJK KR on Android) — different on
/// each, and outside our control.
///
/// This has to be applied *after* the `GoogleFonts.x(...)` call: google_fonts
/// overwrites `fontFamilyFallback` with the bare family name on the way out
/// (`google_fonts_base.dart`), so a fallback passed into it is discarded.
///
/// Latin text is unaffected — it renders from the Google face and never reaches
/// the fallback.
extension KoreanFontFallback on TextStyle {
  TextStyle get kr => copyWith(fontFamilyFallback: _koreanFallback);
}

/// [TextTheme] equivalent of [KoreanFontFallback.kr], applied to every style at
/// once.
extension KoreanTextThemeFallback on TextTheme {
  TextTheme get kr => apply(fontFamilyFallback: _koreanFallback);
}
