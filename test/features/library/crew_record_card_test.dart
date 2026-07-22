import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/library/crew_record_section.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/crew_campaign.dart';

void main() {
  Widget wrap(CrewCampaign campaign, ValueChanged<CrewCampaign> onChanged) {
    return MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: CrewRecordCard(campaign: campaign, onChanged: onChanged),
      ),
    );
  }

  testWidgets('renders crew members and current mission', (tester) async {
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: ['Alice', 'Bob'], currentMission: 14),
        (_) {},
      ),
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text(' / 50'), findsOneWidget);
  });

  testWidgets('shows empty state with no crew members', (tester) async {
    await tester.pumpWidget(
      wrap(const CrewCampaign(crewMembers: [], currentMission: 1), (_) {}),
    );
    expect(find.text('No crew members yet'), findsOneWidget);
  });

  testWidgets('arrows step the mission up and down', (tester) async {
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: [], currentMission: 14),
        (c) => changed = c,
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(changed!.currentMission, 15);

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(changed!.currentMission, 13);
  });

  testWidgets('arrows are disabled at mission bounds', (tester) async {
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: [], currentMission: 1),
        (c) => changed = c,
      ),
    );
    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(changed, isNull);

    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: [], currentMission: 50),
        (c) => changed = c,
      ),
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(changed, isNull);
  });

  testWidgets('tapping the mission number opens a dialog and sets a clamped '
      'value', (tester) async {
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: [], currentMission: 14),
        (c) => changed = c,
      ),
    );

    await tester.tap(find.text('14'));
    await tester.pumpAndSettle();
    expect(find.text('Set current mission'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '99');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changed!.currentMission, 50);
  });

  testWidgets('add dialog appends a trimmed crew member', (tester) async {
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: ['Alice'], currentMission: 3),
        (c) => changed = c,
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Carol ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changed!.crewMembers, ['Alice', 'Carol']);
    expect(changed!.currentMission, 3);
  });

  testWidgets('duplicate and empty names are ignored', (tester) async {
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: ['Alice'], currentMission: 3),
        (c) => changed = c,
      ),
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
    CrewCampaign? changed;
    await tester.pumpWidget(
      wrap(
        const CrewCampaign(crewMembers: ['Alice', 'Bob'], currentMission: 3),
        (c) => changed = c,
      ),
    );

    await tester.tap(find.byIcon(Icons.close).first);
    expect(changed!.crewMembers, ['Bob']);
  });
}
