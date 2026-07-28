import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/sushi_go/sushi_go_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: SushiGoCalculatorScreen(),
);

void main() {
  group('sushiGoTotal', () {
    test('all zeros -> 0', () {
      expect(
        sushiGoTotal(
          maki: 0,
          tempuraSashimiDumpling: 0,
          nigiri: 0,
          puddings: 0,
        ),
        0,
      );
    });

    test('negative pudding score lowers the total', () {
      // 6 maki + 15 sets + 12 nigiri - 4 puddings = 29.
      expect(
        sushiGoTotal(
          maki: 6,
          tempuraSashimiDumpling: 15,
          nigiri: 12,
          puddings: -4,
        ),
        29,
      );
    });
  });

  group('sushiGoWinners', () {
    test('single highest total wins', () {
      expect(sushiGoWinners([29, 25, 33]), [2]);
    });

    test('tied totals share the win', () {
      expect(sushiGoWinners([29, 29, 20]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(sushiGoWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SUSHI GO!'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Maki 6 + sets 15 = 21 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '6');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tester.pump();

    expect(find.text('21'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
