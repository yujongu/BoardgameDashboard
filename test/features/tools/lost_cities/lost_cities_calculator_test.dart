import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/lost_cities/expedition_column.dart';
import 'package:board_game_dashboard/features/tools/lost_cities/lost_cities_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

void main() {
  group('calculateExpeditionScore', () {
    test('no cards and no handshakes -> 0', () {
      expect(calculateExpeditionScore(const [], 0), 0);
    });

    test('a wager with no cards is -20 times the multiplier', () {
      // -20 base, doubled by one handshake.
      expect(calculateExpeditionScore(const [], 1), -40);
    });

    test('cards without a wager: sum minus the 20 investment', () {
      expect(calculateExpeditionScore(const [2, 3, 4], 0), -11); // -20 + 9
    });

    test('each handshake adds a multiplier', () {
      expect(calculateExpeditionScore(const [2, 3, 4], 1), -22); // (-20+9)*2
    });

    test('eight or more cards grant the +20 bonus', () {
      // sum 2..9 = 44; -20+44 = 24; x1; +20 bonus = 44
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7, 8, 9], 0), 44);
    });

    test('the +20 bonus is applied after the wager multiplier', () {
      // 24 * (2+1) = 72; + 20 bonus = 92
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7, 8, 9], 2), 92);
    });

    // ── The 8-card boundary counts wagers as cards ────────────────────────────
    // Regression cases for defects.md D6: the bonus used to test only
    // selectedNumbers.length, so any expedition that reached 8 cards *with* a
    // wager silently lost exactly 20 points.

    test('wagers count toward the eight-card bonus', () {
      // 2 wagers + 6 numbers = 8 cards. -20+27 = 7; 7*3 = 21; +20 bonus = 41.
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7], 2), 41);
    });

    test('the boundary holds at exactly eight cards for every wager count', () {
      // Each row is 8 total cards: (8 - wagers) numbers starting at 2.
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7, 8, 9], 0), 44);
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7, 8], 1), 50);
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7], 2), 41);
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6], 3), 20);
    });

    test('seven total cards still earn no bonus', () {
      // 1 wager + 6 numbers = 7 cards. -20+27 = 7; 7*2 = 14; no bonus.
      expect(calculateExpeditionScore(const [2, 3, 4, 5, 6, 7], 1), 14);
      // 3 wagers + 4 numbers = 7 cards. -20+14 = -6; -6*4 = -24; no bonus.
      expect(calculateExpeditionScore(const [2, 3, 4, 5], 3), -24);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: LostCitiesCalculatorScreen(),
      ),
    );
    expect(find.text('LOST CITIES'), findsOneWidget);
  });
}
