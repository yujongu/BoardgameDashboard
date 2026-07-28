import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/lost_ruins_of_arnak/lost_ruins_of_arnak_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: LostRuinsOfArnakCalculatorScreen(),
);

void main() {
  group('lostRuinsOfArnakTotal', () {
    test('all zeros -> 0', () {
      expect(
        lostRuinsOfArnakTotal(research: 0, idols: 0, cards: 0, trophies: 0),
        0,
      );
    });

    test('straight sum of the four categories', () {
      expect(
        lostRuinsOfArnakTotal(research: 30, idols: 12, cards: 8, trophies: 6),
        56,
      );
    });
  });

  group('lostRuinsOfArnakWinners', () {
    test('single highest total wins', () {
      expect(lostRuinsOfArnakWinners([56, 50, 60]), [2]);
    });

    test('tied totals share the win', () {
      expect(lostRuinsOfArnakWinners([56, 56, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(lostRuinsOfArnakWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('LOST RUINS OF ARNAK'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Research 30 + idols 12 = 42 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
