import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/plays/add_play_notifier.dart';
import 'package:board_game_dashboard/features/plays/add_play_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/campaign.dart';
import 'package:board_game_dashboard/shared/models/catalog_game.dart';

import '../../helpers/analytics.dart';

MaterialApp _app({Widget home = const AddPlayScreen()}) => MaterialApp(
  theme: buildDarkTheme(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: home,
);

void main() {
  testWidgets('AddPlayScreen renders the session location and notes fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [analyticsOverride], child: _app()),
    );
    await tester.pump();

    expect(find.text('LOG A PLAY'), findsOneWidget);
    expect(find.text('Location (optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
  });

  testWidgets('AddPlayScreen shows a score field per participant row', (
    tester,
  ) async {
    // Seed a single participant (the current user) so one player row renders.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsOverride,
          addPlayProvider.overrideWith(
            (ref) =>
                AddPlayNotifier(currentUserName: 'Me', currentUserId: 'u1'),
          ),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    // The score field renders its em-dash hint while empty — one per row.
    expect(find.text('—'), findsOneWidget);
    // Player name field is seeded with the current user.
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('selecting a co-op campaign game shows the table picker only', (
    tester,
  ) async {
    late AddPlayNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsOverride,
          addPlayProvider.overrideWith((ref) {
            notifier = AddPlayNotifier(
              currentUserName: 'Me',
              currentUserId: 'u1',
            );
            return notifier;
          }),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    notifier.onGameSelected(
      const CatalogGame(
        gameId: 'the-crew-the-quest-for-planet-nine-2019',
        name: 'The Crew',
        minPlayers: 2,
        maxPlayers: 5,
      ),
    );
    await tester.pump();

    // Campaign games lead with the table picker; the record and pass/fail
    // controls only appear once a table is selected.
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('MISSION RECORD'), findsNothing);
    // The old free win/loss + stage picker is gone for campaign games.
    expect(find.text('RESULT'), findsNothing);
    expect(find.text('WON'), findsNothing);
    expect(find.text('LOST'), findsNothing);
    // The competitive winner trophy and score field are hidden for co-op.
    expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('one-shot co-op game keeps the team win/loss result', (
    tester,
  ) async {
    late AddPlayNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsOverride,
          addPlayProvider.overrideWith((ref) {
            notifier = AddPlayNotifier(
              currentUserName: 'Me',
              currentUserId: 'u1',
            );
            return notifier;
          }),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    notifier.onGameSelected(
      const CatalogGame(
        gameId: 'pandemic-2008',
        name: 'Pandemic',
        minPlayers: 2,
        maxPlayers: 4,
      ),
    );
    await tester.pump();

    // No stage board: just the team result, no table.
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('WON'), findsOneWidget);
    expect(find.text('LOST'), findsOneWidget);
    expect(find.text('TABLE'), findsNothing);
  });

  testWidgets(
    'selecting a table shows the mission record and current attempt',
    (tester) async {
      late AddPlayNotifier notifier;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addPlayProvider.overrideWith((ref) {
              notifier = AddPlayNotifier(
                currentUserName: 'Me',
                currentUserId: 'u1',
              );
              return notifier;
            }),
          ],
          child: _app(),
        ),
      );
      await tester.pump();

      notifier.onGameSelected(
        const CatalogGame(
          gameId: 'the-crew-the-quest-for-planet-nine-2019',
          name: 'The Crew',
          minPlayers: 2,
          maxPlayers: 5,
        ),
      );
      // Mission 1 passed in 3 tries → current mission becomes 2.
      notifier.setCampaign(
        const Campaign(
          id: 't1',
          gameId: 'the-crew-the-quest-for-planet-nine-2019',
          gameName: 'The Crew',
          memberIds: ['u1'],
          roster: ['Me'],
          stages: {'1': CampaignStage(completed: true, sessionCount: 3)},
        ),
      );
      await tester.pump();

      expect(find.text('MISSION RECORD'), findsOneWidget);
      expect(find.text('CURRENT MISSION'), findsOneWidget);
      expect(find.text('PASSED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      // Prior mission with its recorded tries appears in the record.
      expect(find.text('Mission 1'), findsOneWidget);
      expect(find.text('3 tries'), findsOneWidget);
    },
  );
}
