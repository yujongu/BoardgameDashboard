import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/concordia/concordia_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: ConcordiaCalculatorScreen(),
);

void main() {
  group('concordiaTotal', () {
    test('all zeros -> 0', () {
      expect(
        concordiaTotal(
          vesta: 0,
          jupiter: 0,
          saturnus: 0,
          mercurius: 0,
          mars: 0,
          minerva: 0,
        ),
        0,
      );
    });

    test('sum of the six god categories', () {
      expect(
        concordiaTotal(
          vesta: 5,
          jupiter: 14,
          saturnus: 10,
          mercurius: 12,
          mars: 8,
          minerva: 15,
        ),
        64,
      );
    });
  });

  group('concordiaWinners', () {
    test('single highest total wins', () {
      expect(concordiaWinners([64, 60, 70]), [2]);
    });

    test('tied totals share the win', () {
      expect(concordiaWinners([64, 64, 50]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(concordiaWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('CONCORDIA'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Vesta 5 + Jupiter 14 = 19 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '5');
    await tester.enterText(find.byType(TextField).at(1), '14');
    await tester.pump();

    expect(find.text('19'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
