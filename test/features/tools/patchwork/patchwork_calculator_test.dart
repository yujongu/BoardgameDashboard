import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/patchwork/patchwork_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: PatchworkCalculatorScreen(),
);

void main() {
  group('patchworkTotal', () {
    test('all zeros -> 0', () {
      expect(patchworkTotal(buttons: 0, special7x7: 0, emptySpaces: 0), 0);
    });

    test('7x7 adds 7 and each empty space costs 2', () {
      // 20 buttons + 1*7 special - 3*2 empty = 21.
      expect(patchworkTotal(buttons: 20, special7x7: 1, emptySpaces: 3), 21);
    });
  });

  group('patchworkWinners', () {
    test('single highest total wins', () {
      expect(patchworkWinners([21, 15]), [0]);
    });

    test('tied totals share the win', () {
      expect(patchworkWinners([18, 18]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(patchworkWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('PATCHWORK'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Buttons 20 + 7x7 bonus 1 (*7) = 27 for player 1.
    await tester.enterText(find.byType(TextField).at(0), '20');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.pump();

    expect(find.text('27'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
