import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/takenoko/takenoko_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: TakenokoCalculatorScreen(),
);

void main() {
  group('takenokoTotal', () {
    test('all zeros -> 0', () {
      expect(takenokoTotal(panda: 0, plots: 0, gardener: 0, emperor: 0), 0);
    });

    test('emperor bonus is worth 2 points', () {
      // 9 panda + 7 plots + 5 gardener + 1*2 emperor = 23.
      expect(takenokoTotal(panda: 9, plots: 7, gardener: 5, emperor: 1), 23);
    });
  });

  group('takenokoWinners', () {
    test('single highest total wins', () {
      expect(takenokoWinners([23, 20, 28]), [2]);
    });

    test('tied totals share the win', () {
      expect(takenokoWinners([23, 23, 15]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(takenokoWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('TAKENOKO'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Panda 10 + plots 8 = 18 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '10');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.pump();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
