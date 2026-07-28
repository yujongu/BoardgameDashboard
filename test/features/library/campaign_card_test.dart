import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/library/campaign_record_section.dart';
import 'package:board_game_dashboard/features/library/campaign_registry.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/campaign.dart';

const _spec = CoopSpec(
  hasCampaign: true,
  stageAxis: StageAxis.mission,
  stageCount: 50,
);

/// Builds a campaign whose furthest-incomplete stage is [current] by marking
/// stages 1..current-1 complete.
Campaign campaignWith({List<String> roster = const [], required int current}) {
  final stages = <String, CampaignStage>{};
  for (var i = 1; i < current; i++) {
    stages['$i'] = const CampaignStage(completed: true);
  }
  return Campaign(
    id: 'c1',
    gameId: 'the-crew-the-quest-for-planet-nine-2019',
    gameName: 'The Crew',
    memberIds: const [],
    roster: roster,
    stages: stages,
  );
}

void main() {
  Widget wrap(Campaign campaign, ValueChanged<Campaign> onChanged) {
    return MaterialApp(
      theme: buildDarkTheme(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: CampaignCard(
          campaign: campaign,
          spec: _spec,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('renders roster and current mission', (tester) async {
    await tester.pumpWidget(
      wrap(campaignWith(roster: ['Alice', 'Bob'], current: 14), (_) {}),
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text(' / 50'), findsOneWidget);
  });

  testWidgets('shows empty state with no crew members', (tester) async {
    await tester.pumpWidget(wrap(campaignWith(current: 1), (_) {}));
    expect(find.text('No crew members yet'), findsOneWidget);
  });

  testWidgets('arrows step the mission up and down', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(
      wrap(campaignWith(current: 14), (c) => changed = c),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(changed!.nextIncompleteStage(50), 15);

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(changed!.nextIncompleteStage(50), 13);
  });

  testWidgets('arrows are disabled at mission bounds', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(wrap(campaignWith(current: 1), (c) => changed = c));
    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(changed, isNull);

    await tester.pumpWidget(
      wrap(campaignWith(current: 50), (c) => changed = c),
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(changed, isNull);
  });

  testWidgets(
    'tapping the mission number opens a dialog and clamps the value',
    (tester) async {
      Campaign? changed;
      await tester.pumpWidget(
        wrap(campaignWith(current: 14), (c) => changed = c),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      expect(find.text('Mission'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '99');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(changed!.nextIncompleteStage(50), 50);
    },
  );

  testWidgets('add dialog appends a trimmed crew member', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(
      wrap(campaignWith(roster: ['Alice'], current: 3), (c) => changed = c),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Carol ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changed!.roster, ['Alice', 'Carol']);
  });

  testWidgets('duplicate and empty names are ignored', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(
      wrap(campaignWith(roster: ['Alice'], current: 3), (c) => changed = c),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changed, isNull);

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changed, isNull);
  });

  testWidgets('tapping a chip close icon removes that member', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(
      wrap(
        campaignWith(roster: ['Alice', 'Bob'], current: 3),
        (c) => changed = c,
      ),
    );

    await tester.tap(find.byIcon(Icons.close).first);
    expect(changed!.roster, ['Bob']);
  });

  // ── Undo for the latched stage (defects.md D13) ───────────────────────────
  //
  // Campaign progress latches by design: logging a won mission completes it and
  // deleting that play does not rewind the board. Without an undo there was no
  // way to take back a mission completed by mistake, or to correct the tries a
  // deleted play left behind — the ± stepper can un-complete a run of stages
  // but deliberately preserves each stage's recorded tries.

  testWidgets('offers to correct the last completed mission', (tester) async {
    await tester.pumpWidget(wrap(campaignWith(current: 5), (_) {}));
    expect(find.text('Correct Mission 4'), findsOneWidget);
  });

  testWidgets('offers no correction at the first mission', (tester) async {
    // Nothing is complete yet, so there is nothing to take back.
    await tester.pumpWidget(wrap(campaignWith(current: 1), (_) {}));
    expect(find.textContaining('Correct'), findsNothing);
  });

  testWidgets('un-passing the last mission re-pins it as current', (
    tester,
  ) async {
    Campaign? changed;
    await tester.pumpWidget(wrap(campaignWith(current: 5), (c) => changed = c));

    await tester.tap(find.text('Correct Mission 4'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch)); // Passed -> off
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changed!.isStageCompleted(4), isFalse);
    // Mission 4 is incomplete again, so it becomes the current mission.
    expect(changed!.nextIncompleteStage(_spec.stageCount), 4);
    // Earlier missions are untouched.
    expect(changed!.isStageCompleted(3), isTrue);
  });

  testWidgets('corrects the recorded tries without changing completion', (
    tester,
  ) async {
    Campaign? changed;
    await tester.pumpWidget(wrap(campaignWith(current: 3), (c) => changed = c));

    await tester.tap(find.text('Correct Mission 2'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changed!.triesFor(2), 4);
    expect(changed!.isStageCompleted(2), isTrue);
  });

  testWidgets('cancelling the correction changes nothing', (tester) async {
    Campaign? changed;
    await tester.pumpWidget(wrap(campaignWith(current: 3), (c) => changed = c));

    await tester.tap(find.text('Correct Mission 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(changed, isNull);
  });
}
