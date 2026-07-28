import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/azul/azul_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: AzulCalculatorScreen(),
);

void main() {
  group('azulTotal', () {
    test('all zeros -> 0', () {
      expect(azulTotal(placement: 0, rows: 0, columns: 0, colors: 0), 0);
    });

    test('bonuses use fixed multipliers', () {
      // 30 board + 2 rows*2 + 1 col*7 + 1 colour*10 = 30 + 4 + 7 + 10 = 51.
      expect(azulTotal(placement: 30, rows: 2, columns: 1, colors: 1), 51);
    });
  });

  group('azulWinners', () {
    test('single highest total wins', () {
      expect(azulWinners([51, 47, 60]), [2]);
    });

    test('tied totals share the win', () {
      expect(azulWinners([51, 51, 40]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(azulWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('AZUL'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Placement 30 + rows 2 (*2) = 34 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();

    expect(find.text('34'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
