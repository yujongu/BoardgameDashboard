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

Widget _wrap(List<LibraryEntry> library) => MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: Scaffold(body: StatsRow(library: library)),
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
  // Every figure in this row is competitive-only. Co-op sessions write no
  // library entry and are counted nowhere here -- they are surfaced by the
  // "Recent Sessions" list, whose count is separate on purpose. An earlier
  // version added co-op to PLAYS; that was reversed 2026-07-30 because PLAYS
  // should mean games played competitively.

  testWidgets('PLAYS counts competitive games only', (tester) async {
    // 2 competitive plays logged; any co-op sessions are invisible here because
    // co-op never writes a library entry in the first place.
    await tester.pumpWidget(_wrap([_entry('Catan', plays: 2, wins: 2)]));

    expect(_statFor(tester, 'PLAYS'), '2');
  });

  testWidgets('win rate is competitive-only', (tester) async {
    await tester.pumpWidget(_wrap([_entry('Catan', plays: 2, wins: 2)]));

    expect(_statFor(tester, 'WINS'), '2');
    expect(_statFor(tester, 'WIN RATE'), '100%');
  });

  testWidgets('a co-op-only history reports all zeroes', (tester) async {
    // Nothing competitive logged: the library is empty, so PLAYS is 0 and the
    // win rate has no denominator -- it must read 0% rather than divide by zero.
    await tester.pumpWidget(_wrap([]));

    expect(_statFor(tester, 'PLAYS'), '0');
    expect(_statFor(tester, 'WINS'), '0');
    expect(_statFor(tester, 'WIN RATE'), '0%');
  });

  testWidgets('sums playCount and winCount across the library', (tester) async {
    await tester.pumpWidget(
      _wrap([
        _entry('Catan', plays: 4, wins: 1),
        _entry('Azul', plays: 4, wins: 0),
      ]),
    );

    expect(_statFor(tester, 'PLAYS'), '8');
    expect(_statFor(tester, 'WINS'), '1');
    expect(_statFor(tester, 'WIN RATE'), '12%');
  });
}
