import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/roll_for_the_galaxy/roll_for_the_galaxy_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: RollForTheGalaxyCalculatorScreen(),
);

void main() {
  group('rollForTheGalaxyTotal', () {
    test('all zeros -> 0', () {
      expect(rollForTheGalaxyTotal(tiles: 0, bonuses: 0, credits: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(rollForTheGalaxyTotal(tiles: 32, bonuses: 10, credits: 5), 47);
    });
  });

  group('rollForTheGalaxyWinners', () {
    test('single highest total wins', () {
      expect(rollForTheGalaxyWinners([47, 40, 55]), [2]);
    });

    test('tied totals share the win', () {
      expect(rollForTheGalaxyWinners([47, 47, 30]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(rollForTheGalaxyWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('ROLL FOR THE GALAXY'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Tiles 32 + bonus 10 = 42 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '32');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
