import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/library/campaign_registry.dart';

void main() {
  test(
    'both seeded Crew games map to a campaign spec with the right stage count',
    () {
      final crew1 = campaignForGame('the-crew-the-quest-for-planet-nine-2019');
      expect(crew1?.stageCount, 50);
      expect(crew1?.stageAxis, StageAxis.mission);

      final crew2 = campaignForGame('the-crew-mission-deep-sea-2021');
      expect(crew2?.stageCount, 96);
      expect(crew2?.stageAxis, StageAxis.mission);
    },
  );

  test('a one-shot co-op game is cooperative but has no campaign board', () {
    final pandemic = coopSpecForGame('pandemic-2008');
    expect(pandemic, isNotNull);
    expect(pandemic!.hasCampaign, isFalse);
    // No stage board, so campaignForGame filters it out.
    expect(campaignForGame('pandemic-2008'), isNull);
  });

  test('competitive games have no co-op spec', () {
    expect(coopSpecForGame('wingspan-2019'), isNull);
    expect(campaignForGame('not-a-real-game'), isNull);
  });
}
