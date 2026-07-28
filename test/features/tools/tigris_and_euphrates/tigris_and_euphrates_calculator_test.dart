import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/tigris_and_euphrates/tigris_and_euphrates_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: TigrisAndEuphratesCalculatorScreen(),
);

void main() {
  group('tigrisEuphratesTotal', () {
    test('all zeros -> 0', () {
      expect(tigrisEuphratesTotal(red: 0, blue: 0, green: 0, black: 0), 0);
    });

    test('score is the weakest colour', () {
      expect(tigrisEuphratesTotal(red: 5, blue: 3, green: 4, black: 7), 3);
    });
  });

  group('tigrisEuphratesWinners', () {
    test('highest weakest-colour count wins', () {
      expect(tigrisEuphratesWinners([3, 2, 5]), [2]);
    });

    test('tied totals share the win', () {
      expect(tigrisEuphratesWinners([3, 3, 1]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(tigrisEuphratesWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('TIGRIS & EUPHRATES'), findsOneWidget);
  });

  testWidgets('score reflects the weakest colour', (tester) async {
    await tester.pumpWidget(_app);

    // Weakest of 5/3/4/7 is 3 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '5');
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.enterText(find.byType(TextField).at(2), '4');
    await tester.enterText(find.byType(TextField).at(3), '7');
    await tester.pump();

    expect(find.text('P1 · 3'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
