import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/lords_of_waterdeep/lords_of_waterdeep_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: LordsOfWaterdeepCalculatorScreen(),
);

void main() {
  group('lordsOfWaterdeepTotal', () {
    test('all zeros -> 0', () {
      expect(lordsOfWaterdeepTotal(quests: 0, lordBonus: 0, leftover: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(
        lordsOfWaterdeepTotal(quests: 90, lordBonus: 24, leftover: 6),
        120,
      );
    });
  });

  group('lordsOfWaterdeepWinners', () {
    test('single highest total wins', () {
      expect(lordsOfWaterdeepWinners([120, 110, 130]), [2]);
    });

    test('tied totals share the win', () {
      expect(lordsOfWaterdeepWinners([120, 120, 90]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(lordsOfWaterdeepWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('LORDS OF WATERDEEP'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Quests 90 + lord 24 = 114 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '90');
    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.pump();

    expect(find.text('114'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
