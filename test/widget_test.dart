import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/tools/seven_wonders_duel/seven_wonders_duel_calculator_screen.dart';
import 'package:board_game_dashboard/features/tools/seven_wonders_duel/score_row.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

void main() {
  testWidgets('SevenWondersDuelCalculatorScreen renders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: SevenWondersDuelCalculatorScreen(),
      ),
    );

    expect(find.byType(SevenWondersDuelCalculatorScreen), findsOneWidget);
    expect(
      find.byType(ScoreRow),
      findsNWidgets(SevenWondersCategory.values.length),
    );
  });
}
