import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/puerto_rico/puerto_rico_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: PuertoRicoCalculatorScreen(),
);

void main() {
  group('puertoRicoTotal', () {
    test('all zeros -> 0', () {
      expect(puertoRicoTotal(chips: 0, buildings: 0, largeBonuses: 0), 0);
    });

    test('straight sum of the three categories', () {
      expect(puertoRicoTotal(chips: 40, buildings: 18, largeBonuses: 8), 66);
    });
  });

  group('puertoRicoWinners', () {
    test('single highest total wins', () {
      expect(puertoRicoWinners([66, 60, 70]), [2]);
    });

    test('tied totals share the win', () {
      expect(puertoRicoWinners([66, 66, 50]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(puertoRicoWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('PUERTO RICO'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Chips 40 + buildings 18 = 58 for player 1 (default 3 players).
    await tester.enterText(find.byType(TextField).at(0), '40');
    await tester.enterText(find.byType(TextField).at(1), '18');
    await tester.pump();

    expect(find.text('58'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
