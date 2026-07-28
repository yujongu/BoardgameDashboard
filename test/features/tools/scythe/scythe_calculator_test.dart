import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/scythe/scythe_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: ScytheCalculatorScreen(),
);

void main() {
  group('scytheTotal', () {
    test('all zeros -> 0', () {
      expect(
        scytheTotal(
          coins: 0,
          stars: 0,
          territories: 0,
          resources: 0,
          structureBonus: 0,
        ),
        0,
      );
    });

    test('straight sum of the five categories', () {
      expect(
        scytheTotal(
          coins: 20,
          stars: 18,
          territories: 12,
          resources: 8,
          structureBonus: 3,
        ),
        61,
      );
    });
  });

  group('scytheWinners', () {
    test('single highest total wins', () {
      expect(scytheWinners([61, 55, 70]), [2]);
    });

    test('tied totals share the win', () {
      expect(scytheWinners([61, 61, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(scytheWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SCYTHE'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Coins 20 + stars 18 = 38 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '20');
    await tester.enterText(find.byType(TextField).at(1), '18');
    await tester.pump();

    expect(find.text('38'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
