import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/home/home_tab.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/play.dart';

LibraryEntry _entry(String name, {required int plays, required int wins}) =>
    LibraryEntry(
      gameId: name.toLowerCase(),
      gameName: name,
      playCount: plays,
      winCount: wins,
    );

Widget _wrap(List<LibraryEntry> library, {required int coopPlays}) =>
    MaterialApp(
      theme: buildDarkTheme(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: StatsRow(library: library, coopPlays: coopPlays),
      ),
    );

/// Reads the value rendered above a given stat label.
String _statFor(WidgetTester tester, String label) {
  final column = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: column.first, matching: find.byType(Text)),
      )
      .toList();
  return texts.first.data!;
}

void main() {
  // Co-op plays write no library entry, so PLAYS summed the library and
  // disagreed with the session list below it — "2 PLAYS" above four cards.
  // Co-op now counts toward PLAYS but is deliberately kept out of the win rate.

  testWidgets('PLAYS counts co-op sessions alongside competitive ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([_entry('Catan', plays: 2, wins: 2)], coopPlays: 2),
    );

    expect(_statFor(tester, 'PLAYS'), '4');
  });

  testWidgets('win rate ignores co-op sessions', (tester) async {
    // 2 competitive plays, both won, plus 2 co-op sessions. The co-op games have
    // no individual winner, so the rate stays 100% rather than falling to 50%.
    await tester.pumpWidget(
      _wrap([_entry('Catan', plays: 2, wins: 2)], coopPlays: 2),
    );

    expect(_statFor(tester, 'WINS'), '2');
    expect(_statFor(tester, 'WIN RATE'), '100%');
  });

  testWidgets('a co-op-only history reports plays without a win rate', (
    tester,
  ) async {
    // Nothing competitive has been logged, so the win rate has no denominator
    // and must read 0% rather than divide by zero.
    await tester.pumpWidget(_wrap([], coopPlays: 3));

    expect(_statFor(tester, 'PLAYS'), '3');
    expect(_statFor(tester, 'WINS'), '0');
    expect(_statFor(tester, 'WIN RATE'), '0%');
  });

  testWidgets('with no co-op sessions the figures are unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([
        _entry('Catan', plays: 4, wins: 1),
        _entry('Azul', plays: 4, wins: 0),
      ], coopPlays: 0),
    );

    expect(_statFor(tester, 'PLAYS'), '8');
    expect(_statFor(tester, 'WINS'), '1');
    expect(_statFor(tester, 'WIN RATE'), '12%');
  });
}
