import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/point_salad/point_salad_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: PointSaladCalculatorScreen(),
);

void main() {
  group('pointSaladTotal', () {
    test('all zeros -> 0', () {
      expect(pointSaladTotal([0, 0, 0, 0, 0, 0]), 0);
    });

    test('sums cards including negative ones', () {
      // 12 + 8 + 6 - 4 + 5 + 0 = 27.
      expect(pointSaladTotal([12, 8, 6, -4, 5, 0]), 27);
    });
  });

  group('pointSaladWinners', () {
    test('single highest total wins', () {
      expect(pointSaladWinners([27, 20, 33]), [2]);
    });

    test('tied totals share the win', () {
      expect(pointSaladWinners([27, 27, 15]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(pointSaladWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('POINT SALAD'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Card 1 (12) + card 2 (8) = 20 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '12');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.pump();

    expect(find.text('20'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
