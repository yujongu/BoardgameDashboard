import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/everdell/everdell_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: EverdellCalculatorScreen(),
);

void main() {
  group('everdellTotal', () {
    test('all zeros -> 0', () {
      expect(everdellTotal(cards: 0, tokens: 0, prosperity: 0, events: 0), 0);
    });

    test('straight sum of the four categories', () {
      expect(
        everdellTotal(cards: 30, tokens: 8, prosperity: 12, events: 9),
        59,
      );
    });
  });

  group('everdellWinners', () {
    test('single highest total wins', () {
      expect(everdellWinners([59, 50, 65]), [2]);
    });

    test('tied totals share the win', () {
      expect(everdellWinners([59, 59, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(everdellWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('EVERDELL'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Cards 30 + tokens 8 = 38 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.pump();

    expect(find.text('38'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
