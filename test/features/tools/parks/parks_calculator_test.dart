import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/parks/parks_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: ParksCalculatorScreen(),
);

void main() {
  group('parksTotal', () {
    test('all zeros -> 0', () {
      expect(parksTotal(parkCards: 0, photos: 0, gearBonus: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(parksTotal(parkCards: 22, photos: 6, gearBonus: 8), 36);
    });
  });

  group('parksWinners', () {
    test('single highest total wins', () {
      expect(parksWinners([36, 30, 40]), [2]);
    });

    test('tied totals share the win', () {
      expect(parksWinners([36, 36, 20]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(parksWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('PARKS'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Park cards 22 + photos 6 = 28 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '22');
    await tester.enterText(find.byType(TextField).at(1), '6');
    await tester.pump();

    expect(find.text('28'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
