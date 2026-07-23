import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/library/campaign_registry.dart';

void main() {
  test('both seeded Crew games map to a spec with the right mission count', () {
    expect(
      campaignForGame('the-crew-the-quest-for-planet-nine-2019')?.missionCount,
      50,
    );
    expect(campaignForGame('the-crew-mission-deep-sea-2021')?.missionCount, 96);
  });

  test('games without a campaign sheet return null', () {
    expect(campaignForGame('wingspan-2019'), isNull);
    expect(campaignForGame('not-a-real-game'), isNull);
  });
}
