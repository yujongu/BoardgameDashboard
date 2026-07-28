import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/kingdomino/kingdomino_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: KingdominoCalculatorScreen(),
);

void main() {
  group('kingdominoTotal', () {
    test('all zeros -> 0', () {
      expect(kingdominoTotal(kingdom: 0, middleKingdom: 0, harmony: 0), 0);
    });

    test('variant bonuses add 10 and 5', () {
      // 34 kingdom + 1*10 middle + 1*5 harmony = 49.
      expect(kingdominoTotal(kingdom: 34, middleKingdom: 1, harmony: 1), 49);
    });
  });

  group('kingdominoWinners', () {
    test('single highest total wins', () {
      expect(kingdominoWinners([49, 40, 55]), [2]);
    });

    test('tied totals share the win', () {
      expect(kingdominoWinners([49, 49, 30]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(kingdominoWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('KINGDOMINO'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Kingdom 34 + Middle Kingdom 1 (*10) = 44 for player 1 (default 2).
    await tester.enterText(find.byType(TextField).at(0), '34');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.pump();

    expect(find.text('44'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
