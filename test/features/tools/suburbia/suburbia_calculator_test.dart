import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/suburbia/suburbia_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: SuburbiaCalculatorScreen(),
);

void main() {
  group('suburbiaTotal', () {
    test('all zeros -> 0', () {
      expect(
        suburbiaTotal(
          population: 0,
          personalGoal: 0,
          publicGoals: 0,
          bonusMarkers: 0,
        ),
        0,
      );
    });

    test('straight sum of the four categories', () {
      expect(
        suburbiaTotal(
          population: 45,
          personalGoal: 20,
          publicGoals: 15,
          bonusMarkers: 6,
        ),
        86,
      );
    });
  });

  group('suburbiaWinners', () {
    test('single highest total wins', () {
      expect(suburbiaWinners([86, 80, 90]), [2]);
    });

    test('tied totals share the win', () {
      expect(suburbiaWinners([86, 86, 60]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(suburbiaWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SUBURBIA'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Population 45 + personal goal 20 = 65 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '45');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.pump();

    expect(find.text('65'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
