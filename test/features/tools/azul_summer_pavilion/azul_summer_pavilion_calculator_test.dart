import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/azul_summer_pavilion/azul_summer_pavilion_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: AzulSummerPavilionCalculatorScreen(),
);

void main() {
  group('azulSummerPavilionTotal', () {
    test('all zeros -> 0', () {
      expect(
        azulSummerPavilionTotal(roundPlacement: 0, starBonuses: 0, leftover: 0),
        0,
      );
    });

    test('leftover tiles subtract one point each', () {
      // 40 rounds + 20 stars - 3 leftover = 57.
      expect(
        azulSummerPavilionTotal(
          roundPlacement: 40,
          starBonuses: 20,
          leftover: 3,
        ),
        57,
      );
    });
  });

  group('azulSummerPavilionWinners', () {
    test('single highest total wins', () {
      expect(azulSummerPavilionWinners([57, 50, 61]), [2]);
    });

    test('tied totals share the win', () {
      expect(azulSummerPavilionWinners([57, 57, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(azulSummerPavilionWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SUMMER PAVILION'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Rounds 40 + stars 20 - leftover 3 = 57 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '40');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pump();

    expect(find.text('57'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
