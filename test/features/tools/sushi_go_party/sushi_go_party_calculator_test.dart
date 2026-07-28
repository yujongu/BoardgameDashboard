import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/sushi_go_party/sushi_go_party_calculator_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

final _app = MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: SushiGoPartyCalculatorScreen(),
);

void main() {
  group('sushiGoPartyTotal', () {
    test('all zeros -> 0', () {
      expect(
        sushiGoPartyTotal(
          nigiri: 0,
          rolls: 0,
          appetizers: 0,
          specials: 0,
          desserts: 0,
        ),
        0,
      );
    });

    test('negative dessert score lowers the total', () {
      // 10 nigiri + 8 rolls + 12 appetizers + 5 specials - 3 desserts = 32.
      expect(
        sushiGoPartyTotal(
          nigiri: 10,
          rolls: 8,
          appetizers: 12,
          specials: 5,
          desserts: -3,
        ),
        32,
      );
    });
  });

  group('sushiGoPartyWinners', () {
    test('single highest total wins', () {
      expect(sushiGoPartyWinners([32, 28, 40]), [2]);
    });

    test('tied totals share the win', () {
      expect(sushiGoPartyWinners([32, 32, 20]), [0, 1]);
    });

    test('empty input -> empty result', () {
      expect(sushiGoPartyWinners(const []), isEmpty);
    });
  });

  testWidgets('screen builds without throwing', (tester) async {
    await tester.pumpWidget(_app);
    expect(find.text('SUSHI GO PARTY!'), findsOneWidget);
  });

  testWidgets('entering scores updates the selected player total', (
    tester,
  ) async {
    await tester.pumpWidget(_app);

    // Nigiri 10 + rolls 8 = 18 for player 1 (default 2 players).
    await tester.enterText(find.byType(TextField).at(0), '10');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.pump();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
  });
}
