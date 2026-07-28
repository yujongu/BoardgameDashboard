import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/blokus/blokus_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: BlokusCalculatorScreen(),
);

void main() {
  group('blokusTotal', () {
    test('remaining squares give a negative score', () {
      expect(blokusTotal(remaining: 5, allPlaced: 0, monomino: 0), -5);
    });

    test('all-placed and monomino bonuses add 15 and 5', () {
      expect(blokusTotal(remaining: 0, allPlaced: 1, monomino: 1), 20);
    });
  });

  group('blokusWinners', () {
    test('single highest total wins', () {
      expect(blokusWinners([20, 5, -3]), [0]);
    });

    test('tied totals share the win', () {
      expect(blokusWinners([-5, -5, -10]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(blokusWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('BLOKUS'), findsOneWidget);
  });

  testWidgets('entering bonuses updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // All placed (+15) and final monomino (+5) = 20 for player 1.
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.enterText(find.byType(TextField).at(2), '1');
    await tester.pump();

    expect(find.text('20'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
