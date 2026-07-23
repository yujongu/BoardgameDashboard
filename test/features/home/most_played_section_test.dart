import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/home/home_tab.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/play.dart';

LibraryEntry _entry(String name, int plays) => LibraryEntry(
  gameId: name.toLowerCase(),
  gameName: name,
  playCount: plays,
  winCount: 0,
);

Widget _wrap(List<LibraryEntry> library) => MaterialApp(
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: Scaffold(body: MostPlayedSection(library: library)),
);

void main() {
  testWidgets('ranks by play count, caps at 5, and drops zero-play games', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([
        _entry('Root', 3),
        _entry('Azul', 10),
        _entry('Go', 0), // zero plays — excluded
        _entry('Splendor', 6),
        _entry('Chess', 1), // 6th highest — beyond top 5
        _entry('Catan', 8),
        _entry('Wingspan', 5),
      ]),
    );
    await tester.pump();

    expect(find.text('Most Played'), findsOneWidget);
    // Top 5 by play count are shown.
    for (final name in ['Azul', 'Catan', 'Splendor', 'Wingspan', 'Root']) {
      expect(find.text(name), findsOneWidget);
    }
    // The play count of the leader is rendered.
    expect(find.text('10'), findsOneWidget);
    // Beyond top-5 and zero-play games are excluded.
    expect(find.text('Chess'), findsNothing);
    expect(find.text('Go'), findsNothing);
  });

  testWidgets('renders nothing when no game has been played', (tester) async {
    await tester.pumpWidget(_wrap([_entry('Go', 0), _entry('Chess', 0)]));
    await tester.pump();

    expect(find.text('Most Played'), findsNothing);
  });
}
