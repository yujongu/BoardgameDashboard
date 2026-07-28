import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/ticket_to_ride/ticket_to_ride_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: TicketToRideCalculatorScreen(),
);

void main() {
  group('ticketToRideTotal', () {
    test('all zeros -> 0', () {
      expect(
        ticketToRideTotal(
          routes: 0,
          ticketsDone: 0,
          ticketsFailed: 0,
          longest: 0,
        ),
        0,
      );
    });

    test('failed tickets subtract and longest route adds 10', () {
      // 74 routes + 20 done - 5 failed + 1*10 = 99.
      expect(
        ticketToRideTotal(
          routes: 74,
          ticketsDone: 20,
          ticketsFailed: 5,
          longest: 1,
        ),
        99,
      );
    });
  });

  group('ticketToRideWinners', () {
    test('single highest total wins', () {
      expect(ticketToRideWinners([99, 90, 110]), [2]);
    });

    test('tied totals share the win', () {
      expect(ticketToRideWinners([99, 99, 80]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(ticketToRideWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('TICKET TO RIDE'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Routes 74 + tickets 20 = 94 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '74');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.pump();

    expect(find.text('94'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
