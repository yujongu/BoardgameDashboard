import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/stone_age/stone_age_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: StoneAgeCalculatorScreen(),
);

void main() {
  group('stoneAgeTotal', () {
    test('all zeros -> 0', () {
      expect(
        stoneAgeTotal(
          inGame: 0,
          buildings: 0,
          greenCards: 0,
          multiplierCards: 0,
        ),
        0,
      );
    });

    test('straight sum of the four categories', () {
      expect(
        stoneAgeTotal(
          inGame: 78,
          buildings: 40,
          greenCards: 24,
          multiplierCards: 16,
        ),
        158,
      );
    });
  });

  group('stoneAgeWinners', () {
    test('single highest total wins', () {
      expect(stoneAgeWinners([158, 140, 170]), [2]);
    });

    test('tied totals share the win', () {
      expect(stoneAgeWinners([158, 158, 120]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(stoneAgeWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('STONE AGE'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // In-game 78 + buildings 40 = 118 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '78');
    await tester.enterText(find.byType(TextField).at(1), '40');
    await tester.pump();

    expect(find.text('118'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
