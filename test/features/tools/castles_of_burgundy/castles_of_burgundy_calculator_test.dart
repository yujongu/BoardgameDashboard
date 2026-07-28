import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/castles_of_burgundy/castles_of_burgundy_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: CastlesOfBurgundyCalculatorScreen(),
);

void main() {
  group('castlesOfBurgundyTotal', () {
    test('all zeros -> 0', () {
      expect(
        castlesOfBurgundyTotal(inGame: 0, regionBonuses: 0, leftover: 0),
        0,
      );
    });

    test('straight sum of the three categories', () {
      expect(
        castlesOfBurgundyTotal(inGame: 160, regionBonuses: 24, leftover: 7),
        191,
      );
    });
  });

  group('castlesOfBurgundyWinners', () {
    test('single highest total wins', () {
      expect(castlesOfBurgundyWinners([191, 180, 200]), [2]);
    });

    test('tied totals share the win', () {
      expect(castlesOfBurgundyWinners([191, 191, 150]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(castlesOfBurgundyWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('CASTLES OF BURGUNDY'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // In-game 160 + region 24 = 184 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '160');
    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.pump();

    expect(find.text('184'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
