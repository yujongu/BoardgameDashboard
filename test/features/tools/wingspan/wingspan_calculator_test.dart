import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/wingspan/wingspan_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: WingspanCalculatorScreen(),
);

void main() {
  group('wingspanTotal', () {
    test('all zeros -> 0', () {
      final total = wingspanTotal(
        birds: 0,
        bonusCards: 0,
        roundGoals: 0,
        eggs: 0,
        cachedFood: 0,
        tuckedCards: 0,
      );
      expect(total, 0);
    });

    test('straight sum of all six categories', () {
      final total = wingspanTotal(
        birds: 40,
        bonusCards: 11,
        roundGoals: 9,
        eggs: 14,
        cachedFood: 3,
        tuckedCards: 6,
      );
      expect(total, 83);
    });
  });

  group('wingspanWinners', () {
    test('single highest total wins', () {
      expect(wingspanWinners([83, 79, 90]), [2]);
    });

    test('tied totals share the win', () {
      expect(wingspanWinners([83, 83, 60]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(wingspanWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('WINGSPAN'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Birds 40 + eggs 14 = 54 for player 1 (default 2 players).
    await tester.enterText(find.widgetWithText(TextField, '').at(0), '40');
    await tester.enterText(find.widgetWithText(TextField, '').at(3), '14');
    await tester.pump();

    expect(find.text('54'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
