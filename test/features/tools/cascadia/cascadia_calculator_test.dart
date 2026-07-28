import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/cascadia/cascadia_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: CascadiaCalculatorScreen(),
);

void main() {
  group('cascadiaTotal', () {
    test('all zeros -> 0', () {
      expect(cascadiaTotal(wildlife: 0, habitat: 0, nature: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(cascadiaTotal(wildlife: 42, habitat: 30, nature: 4), 76);
    });
  });

  group('cascadiaWinners', () {
    test('single highest total wins', () {
      expect(cascadiaWinners([76, 70, 80]), [2]);
    });

    test('tied totals share the win', () {
      expect(cascadiaWinners([76, 76, 60]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(cascadiaWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('CASCADIA'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Wildlife 42 + habitat 30 = 72 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '42');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.pump();

    expect(find.text('72'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
