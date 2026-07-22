import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/plays/play_history_page.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/play.dart';
import 'package:board_game_dashboard/shared/providers/repository_providers.dart';
import 'package:board_game_dashboard/shared/repositories/play_repository.dart';

PlaySummary _play(String id, String name) => PlaySummary(
  playId: id,
  gameId: id,
  gameName: name,
  playedAt: DateTime(2024, 1, 1),
  participantCount: 2,
);

/// Fake that returns the given pages in order. Only [listMyPlays] is used;
/// everything else routes through noSuchMethod (and would throw if called).
class _FakePlayRepo implements PlayRepository {
  _FakePlayRepo(this.pages);

  final List<ListMyPlaysResult> pages;
  int calls = 0;

  @override
  Future<ListMyPlaysResult> listMyPlays({
    int limit = 20,
    String? cursor,
  }) async {
    final page = pages[calls.clamp(0, pages.length - 1)];
    calls++;
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(PlayRepository repo) => ProviderScope(
  overrides: [playRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: const PlayHistoryPage(),
  ),
);

void main() {
  testWidgets('renders the first page of plays', (tester) async {
    final repo = _FakePlayRepo([
      ListMyPlaysResult(
        plays: [_play('p1', 'Azul'), _play('p2', 'Catan')],
        nextCursor: null,
      ),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump(); // schedule the first page load
    await tester.pump(); // let the future resolve and rebuild

    expect(find.text('PLAY HISTORY'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('Catan'), findsOneWidget);
  });

  testWidgets('loads the next page when scrolled to the bottom', (
    tester,
  ) async {
    final page1 = List.generate(20, (i) => _play('a$i', 'Game $i'));
    final repo = _FakePlayRepo([
      ListMyPlaysResult(plays: page1, nextCursor: 'c1'),
      ListMyPlaysResult(plays: [_play('z', 'ZZZ Last')], nextCursor: null),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();

    // Page 2 not fetched yet.
    expect(find.text('ZZZ Last'), findsNothing);
    expect(repo.calls, 1);

    // Scroll to the bottom to trigger the next-page load.
    await tester.drag(find.byType(Scrollable), const Offset(0, -6000));
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    expect(find.text('ZZZ Last'), findsOneWidget);
  });
}
