import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/sagrada/sagrada_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: SagradaCalculatorScreen(),
);

void main() {
  group('sagradaTotal', () {
    test('all zeros -> 0', () {
      expect(
        sagradaTotal(
          publicObjectives: 0,
          privateObjective: 0,
          favorTokens: 0,
          emptySpaces: 0,
        ),
        0,
      );
    });

    test('empty spaces subtract one point each', () {
      // 24 public + 10 private + 2 favor - 3 empty = 33.
      expect(
        sagradaTotal(
          publicObjectives: 24,
          privateObjective: 10,
          favorTokens: 2,
          emptySpaces: 3,
        ),
        33,
      );
    });
  });

  group('sagradaWinners', () {
    test('single highest total wins', () {
      expect(sagradaWinners([33, 30, 40]), [2]);
    });

    test('tied totals share the win', () {
      expect(sagradaWinners([33, 33, 20]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(sagradaWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SAGRADA'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Public 24 + private 10 = 34 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pump();

    expect(find.text('34'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
