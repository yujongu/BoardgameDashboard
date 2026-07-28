import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/ticket_to_ride_europe/ticket_to_ride_europe_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: TicketToRideEuropeCalculatorScreen(),
);

void main() {
  group('ticketToRideEuropeTotal', () {
    test('all zeros -> 0', () {
      expect(
        ticketToRideEuropeTotal(
          routes: 0,
          ticketsDone: 0,
          ticketsFailed: 0,
          longest: 0,
          stations: 0,
        ),
        0,
      );
    });

    test('longest route adds 10 and each station adds 4', () {
      // 60 routes + 18 done - 4 failed + 1*10 + 2*4 = 92.
      expect(
        ticketToRideEuropeTotal(
          routes: 60,
          ticketsDone: 18,
          ticketsFailed: 4,
          longest: 1,
          stations: 2,
        ),
        92,
      );
    });
  });

  group('ticketToRideEuropeWinners', () {
    test('single highest total wins', () {
      expect(ticketToRideEuropeWinners([92, 88, 100]), [2]);
    });

    test('tied totals share the win', () {
      expect(ticketToRideEuropeWinners([92, 92, 70]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(ticketToRideEuropeWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('TTR: EUROPE'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Routes 60 + tickets 18 = 78 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '60');
    await tester.enterText(find.byType(TextField).at(1), '18');
    await tester.pump();

    expect(find.text('78'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
