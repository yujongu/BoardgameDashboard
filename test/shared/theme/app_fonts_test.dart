import 'dart:io';

import 'package:board_game_dashboard/shared/theme/app_colors.dart';
import 'package:board_game_dashboard/shared/theme/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Korean font fallback', () {
    test('kr adds the bundled Hangul family to a TextStyle', () {
      const style = TextStyle(fontFamily: 'Space Grotesk');

      expect(style.fontFamilyFallback, isNull);
      expect(style.kr.fontFamilyFallback, contains(kKoreanFontFamily));
      // The Latin face must survive — the fallback is only for missing glyphs.
      expect(style.kr.fontFamily, 'Space Grotesk');
    });

    test('kr adds the fallback to every style in a TextTheme', () {
      const theme = TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Work Sans'),
        headlineSmall: TextStyle(fontFamily: 'Newsreader'),
      );

      expect(
        theme.kr.bodyMedium!.fontFamilyFallback,
        contains(kKoreanFontFamily),
      );
      expect(
        theme.kr.headlineSmall!.fontFamilyFallback,
        contains(kKoreanFontFamily),
      );
    });

    // Guards the wiring end to end: a typo in either the pubspec family name or
    // kKoreanFontFamily would leave Korean text silently falling back to the
    // platform face, which no widget test would otherwise notice.
    test('the bundled family name matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('family: $kKoreanFontFamily'));
    });

    test('every declared font asset exists', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assets = RegExp(
        r'asset: (assets/fonts/[^\s]+)',
      ).allMatches(pubspec).map((m) => m.group(1)!).toList();

      expect(assets, hasLength(4));
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
      }
    });

    testWidgets('the app theme carries the fallback', (tester) async {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        expect(
          theme.textTheme.bodyMedium!.fontFamilyFallback,
          contains(kKoreanFontFamily),
          reason: 'body text must render Hangul in the bundled face',
        );
        expect(
          theme.appBarTheme.titleTextStyle!.fontFamilyFallback,
          contains(kKoreanFontFamily),
        );
      }
    });
  });
}
