import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/calico/calico_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: CalicoCalculatorScreen(),
);

void main() {
  group('calicoTotal', () {
    test('all zeros -> 0', () {
      expect(calicoTotal(cats: 0, buttons: 0, goals: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(calicoTotal(cats: 9, buttons: 12, goals: 14), 35);
    });
  });

  group('calicoWinners', () {
    test('single highest total wins', () {
      expect(calicoWinners([35, 30, 40]), [2]);
    });

    test('tied totals share the win', () {
      expect(calicoWinners([35, 35, 20]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(calicoWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('CALICO'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Cats 9 + buttons 12 = 21 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '9');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.pump();

    expect(find.text('21'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
