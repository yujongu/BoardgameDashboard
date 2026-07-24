import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/seven_wonders/seven_wonders_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: SevenWondersCalculatorScreen(),
);

void main() {
  group('sevenWondersScienceScore', () {
    int science(int tablets, int compasses, int gears) =>
        sevenWondersScienceScore(
          tablets: tablets,
          compasses: compasses,
          gears: gears,
        );

    test('no symbols -> 0', () => expect(science(0, 0, 0), 0));
    test('one complete set -> 10', () => expect(science(1, 1, 1), 10));
    test('two complete sets -> 26', () => expect(science(2, 2, 2), 26));
    test('3/2/1 -> 21', () => expect(science(3, 2, 1), 21));
    test('single symbol type only squares -> 16', () {
      expect(science(4, 0, 0), 16);
    });
  });

  group('sevenWondersClassicTotal', () {
    test('mixed categories with negative military and coin floor', () {
      final total = sevenWondersClassicTotal(
        military: -2,
        coins: 7, // -> 2 VP
        wonders: 10,
        civilian: 12,
        commercial: 4,
        guilds: 8,
        tablets: 2, // science 2/1/1 -> 4+1+1+7 = 13
        compasses: 1,
        gears: 1,
      );
      expect(total, -2 + 2 + 10 + 12 + 4 + 8 + 13);
    });

    test('coin floor: 2 coins -> 0 VP, 3 coins -> 1 VP', () {
      int coinsOnly(int coins) => sevenWondersClassicTotal(
        military: 0,
        coins: coins,
        wonders: 0,
        civilian: 0,
        commercial: 0,
        guilds: 0,
        tablets: 0,
        compasses: 0,
        gears: 0,
      );
      expect(coinsOnly(2), 0);
      expect(coinsOnly(3), 1);
      expect(coinsOnly(8), 2);
    });
  });

  group('sevenWondersClassicWinners', () {
    test('single highest total wins outright', () {
      final winners = sevenWondersClassicWinners(
        totals: [40, 55, 47],
        coins: [10, 0, 20],
      );
      expect(winners, [1]);
    });

    test('total tie broken by most coins', () {
      final winners = sevenWondersClassicWinners(
        totals: [50, 50, 30],
        coins: [4, 9, 20],
      );
      expect(winners, [1]);
    });

    test('tie on total and coins -> shared victory', () {
      final winners = sevenWondersClassicWinners(
        totals: [50, 50, 50],
        coins: [9, 9, 3],
      );
      expect(winners, [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(
        sevenWondersClassicWinners(totals: const [], coins: const []),
        isEmpty,
      );
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('7 WONDERS'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Civilian 12 + coins 7 (-> 2 VP) = 14 for player 1.
    await tester.enterText(
      find.widgetWithText(TextField, '').at(3), // civilian row
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '').at(1), // coins row
      '7',
    );
    await tester.pump();

    expect(find.text('14'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
