import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/race_for_the_galaxy/race_for_the_galaxy_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: RaceForTheGalaxyCalculatorScreen(),
);

void main() {
  group('raceForTheGalaxyTotal', () {
    test('all zeros -> 0', () {
      expect(raceForTheGalaxyTotal(cards: 0, chips: 0, sixDevBonuses: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(raceForTheGalaxyTotal(cards: 28, chips: 14, sixDevBonuses: 9), 51);
    });
  });

  group('raceForTheGalaxyWinners', () {
    test('single highest total wins', () {
      expect(raceForTheGalaxyWinners([51, 45, 60]), [2]);
    });

    test('tied totals share the win', () {
      expect(raceForTheGalaxyWinners([51, 51, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(raceForTheGalaxyWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('RACE FOR THE GALAXY'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Cards 28 + chips 14 = 42 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '28');
    await tester.enterText(find.byType(TextField).at(1), '14');
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
