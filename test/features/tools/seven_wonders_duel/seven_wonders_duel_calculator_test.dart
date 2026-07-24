import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/seven_wonders_duel/seven_wonders_duel_calculator_screen.dart';
import 'package:board_game_dashboard/features/tools/seven_wonders_duel/score_row.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

/// Builds a full category map from individual values (defaults 0).
Map<SevenWondersCategory, int> _map({
  int civilian = 0,
  int science = 0,
  int commercial = 0,
  int guilds = 0,
  int wonders = 0,
  int progress = 0,
  int military = 0,
  int coins = 0,
}) => {
  SevenWondersCategory.civilian: civilian,
  SevenWondersCategory.science: science,
  SevenWondersCategory.commercial: commercial,
  SevenWondersCategory.guilds: guilds,
  SevenWondersCategory.wonders: wonders,
  SevenWondersCategory.progress: progress,
  SevenWondersCategory.military: military,
  SevenWondersCategory.coins: coins,
};

void main() {
  group('sevenWondersGrandTotal — coin floor', () {
    int coinsOnly(int coins) => sevenWondersGrandTotal(
      civilian: 0,
      science: 0,
      commercial: 0,
      guilds: 0,
      wonders: 0,
      progress: 0,
      military: 0,
      coins: coins,
    );

    test('2 coins -> 0 VP', () => expect(coinsOnly(2), 0));
    test('3 coins -> 1 VP', () => expect(coinsOnly(3), 1));
    test('8 coins -> 2 VP', () => expect(coinsOnly(8), 2));
    test('9 coins -> 3 VP', () => expect(coinsOnly(9), 3));
  });

  group('sevenWondersGrandTotal — Case A', () {
    test('player 1 total is 27', () {
      final total = sevenWondersGrandTotal(
        civilian: 5,
        science: 4,
        commercial: 3,
        guilds: 0,
        wonders: 8,
        progress: 2,
        military: 3,
        coins: 7,
      );
      expect(total, 27);
    });

    test('player 2 total is 25', () {
      final total = sevenWondersGrandTotal(
        civilian: 4,
        science: 6,
        commercial: 2,
        guilds: 3,
        wonders: 6,
        progress: 4,
        military: 0,
        coins: 2,
      );
      expect(total, 25);
    });
  });

  group('sevenWondersResult', () {
    test('Case A: player 1 wins outright', () {
      final p1 = _map(
        civilian: 5,
        science: 4,
        commercial: 3,
        wonders: 8,
        progress: 2,
        military: 3,
        coins: 7,
      );
      final p2 = _map(
        civilian: 4,
        science: 6,
        commercial: 2,
        guilds: 3,
        wonders: 6,
        progress: 4,
        coins: 2,
      );
      final result = sevenWondersResult(player1: p1, player2: p2);
      expect(result.winner, SevenWondersWinner.player1);
      expect(result.byTiebreaker, false);
    });

    test('Case B: tiebreaker -> player 1 (higher civilian)', () {
      final p1 = _map(civilian: 6);
      final p2 = _map(civilian: 3, military: 3);
      // Both total 6; p1 civilian 6 > p2 civilian 3.
      expect(sevenWondersTotalOf(p1), 6);
      expect(sevenWondersTotalOf(p2), 6);
      final result = sevenWondersResult(player1: p1, player2: p2);
      expect(result.winner, SevenWondersWinner.player1);
      expect(result.byTiebreaker, true);
    });

    test('Case C: true tie (equal total, equal civilian)', () {
      final p1 = _map(civilian: 4, military: 2);
      final p2 = _map(civilian: 4, military: 2);
      expect(sevenWondersTotalOf(p1), 6);
      expect(sevenWondersTotalOf(p2), 6);
      final result = sevenWondersResult(player1: p1, player2: p2);
      expect(result.winner, SevenWondersWinner.tie);
      expect(result.byTiebreaker, false);
    });

    test('symmetry: player 2 wins outright (swapped Case A)', () {
      final p1 = _map(
        civilian: 4,
        science: 6,
        commercial: 2,
        guilds: 3,
        wonders: 6,
        progress: 4,
        coins: 2,
      );
      final p2 = _map(
        civilian: 5,
        science: 4,
        commercial: 3,
        wonders: 8,
        progress: 2,
        military: 3,
        coins: 7,
      );
      final result = sevenWondersResult(player1: p1, player2: p2);
      expect(result.winner, SevenWondersWinner.player2);
      expect(result.byTiebreaker, false);
    });

    test('tiebreaker favors player 2 (higher civilian)', () {
      final p1 = _map(civilian: 3, military: 3);
      final p2 = _map(civilian: 6);
      expect(sevenWondersTotalOf(p1), 6);
      expect(sevenWondersTotalOf(p2), 6);
      final result = sevenWondersResult(player1: p1, player2: p2);
      expect(result.winner, SevenWondersWinner.player2);
      expect(result.byTiebreaker, true);
    });
  });

  group('sevenWondersTotalOf — map defaults', () {
    test('empty map -> 0', () {
      expect(sevenWondersTotalOf(const {}), 0);
    });

    test('only coins:9 -> 3', () {
      expect(sevenWondersTotalOf(const {SevenWondersCategory.coins: 9}), 3);
    });
  });

  test(
    'consistency: sevenWondersTotalOf(fullMap) == sevenWondersGrandTotal',
    () {
      final fromMap = sevenWondersTotalOf(
        _map(
          civilian: 5,
          science: 4,
          commercial: 3,
          guilds: 0,
          wonders: 8,
          progress: 2,
          military: 3,
          coins: 7,
        ),
      );
      final fromArgs = sevenWondersGrandTotal(
        civilian: 5,
        science: 4,
        commercial: 3,
        guilds: 0,
        wonders: 8,
        progress: 2,
        military: 3,
        coins: 7,
      );
      expect(fromMap, fromArgs);
      expect(fromMap, 27);
    },
  );

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: SevenWondersDuelCalculatorScreen(),
      ),
    );
    expect(find.text('7 WONDERS DUEL'), findsOneWidget);
  });
}
