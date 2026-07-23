/// Per-game campaign-sheet configuration.
///
/// Every campaign today is a "crew roster + current mission out of N" sheet
/// (The Crew games), so the only game-specific value is the mission count.
/// Keyed by Firestore game document ID, this mirrors the tools registry
/// (`game_tools_registry.dart`) so campaign sheets scale the same way tools do:
/// register a game here and its sheet appears on the game detail page.
class CampaignSpec {
  final int missionCount;

  const CampaignSpec({required this.missionCount});
}

const kCampaignRegistry = <String, CampaignSpec>{
  // The Crew: The Quest for Planet Nine — 50-mission logbook.
  'the-crew-the-quest-for-planet-nine-2019': CampaignSpec(missionCount: 50),
  // The Crew: Mission Deep Sea — 96-mission logbook.
  'the-crew-mission-deep-sea-2021': CampaignSpec(missionCount: 96),
};

/// The campaign spec for [gameId], or null if the game has no campaign sheet.
CampaignSpec? campaignForGame(String gameId) => kCampaignRegistry[gameId];
