import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/terraforming_mars/terraforming_mars_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

int _score({
  int terraformRating = 0,
  int milestones = 0,
  int awardVp = 0,
  int greeneries = 0,
  int cityPoints = 0,
  int cardVp = 0,
}) => terraformingMarsTotal(
  terraformRating: terraformRating,
  milestones: milestones,
  awardVp: awardVp,
  greeneries: greeneries,
  cityPoints: cityPoints,
  cardVp: cardVp,
);

void main() {
  group('terraformingMarsTotal', () {
    test('default start (TR 20, nothing else) -> 20', () {
      expect(_score(terraformRating: 20), 20);
    });

    test('milestones are worth 5 VP each', () {
      expect(_score(milestones: 3), 15);
    });

    test('sums every category (milestones x5, the rest x1)', () {
      // 20 + 3*5 + 8 + 4 + 6 + 12 = 65
      expect(
        _score(
          terraformRating: 20,
          milestones: 3,
          awardVp: 8,
          greeneries: 4,
          cityPoints: 6,
          cardVp: 12,
        ),
        65,
      );
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: TerraformingMarsCalculatorScreen(),
      ),
    );
    expect(find.text('TERRAFORMING MARS'), findsOneWidget);
  });

  // D16: the stepper committed only on focus loss, and iOS does not unfocus on
  // an outside tap, so a typed value stayed visible while the total ignored it.
  testWidgets('a typed stepper value commits when you tap outside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: TerraformingMarsCalculatorScreen(),
      ),
    );

    // Card VP is the last row — the one a user types then stops.
    final cardVp = find.byType(TextField).last;
    await tester.tap(cardVp);
    await tester.pump();
    await tester.enterText(cardVp, '12');
    await tester.pump();

    // Tap the row's own label — inside the card, outside the field.
    await tester.tap(find.text('Card VP'));
    await tester.pumpAndSettle();

    // TR starts at 20, so the total must now read 32 — not the stale 20.
    expect(find.text('32'), findsOneWidget);
  });
}
