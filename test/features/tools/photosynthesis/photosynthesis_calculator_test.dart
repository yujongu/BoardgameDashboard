import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/photosynthesis/photosynthesis_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: PhotosynthesisCalculatorScreen(),
);

void main() {
  group('photosynthesisTotal', () {
    test('score equals the scoring tokens', () {
      expect(photosynthesisTotal(tokens: 0), 0);
      expect(photosynthesisTotal(tokens: 47), 47);
    });
  });

  group('photosynthesisWinners', () {
    test('single highest total wins', () {
      expect(photosynthesisWinners(totals: [40, 35, 50], light: [0, 0, 0]), [
        2,
      ]);
    });

    test('tie broken by most remaining light', () {
      expect(photosynthesisWinners(totals: [40, 40], light: [3, 5]), [1]);
    });

    test('players tied on light share the win', () {
      expect(photosynthesisWinners(totals: [40, 40], light: [5, 5]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(photosynthesisWinners(totals: const [], light: const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('PHOTOSYNTHESIS'), findsOneWidget);
  });

  testWidgets('entering scoring tokens updates the total', (tester) async {
    await tester.pumpWidget(_app);

    // Tokens 40 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '40');
    await tester.pump();

    expect(find.text('P1 · 40'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
