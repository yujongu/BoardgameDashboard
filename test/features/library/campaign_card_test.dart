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
}
