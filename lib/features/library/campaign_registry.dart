// Per-game cooperative configuration.
//
// A game listed here is cooperative (team-vs-game, no individual winner).
// Some co-op games also run a campaign — an ordered board of stages the team
// works through (The Crew's missions, Gloomhaven's scenarios); others are
// one-shot co-ops with only a win/loss outcome (Pandemic).
//
// Keyed by Firestore game document ID, this mirrors the tools registry
// (game_tools_registry.dart) so co-op support scales the same way tools do:
// register a game here and the add-play flow + game detail page adapt to it.

/// The axis a campaign's stages are counted along; drives the board's label.
enum StageAxis { mission, scenario, month }

class CoopSpec {
  /// True when the game has an ordered stage board (missions/scenarios/months).
  /// False for one-shot co-ops that only record a win/loss.
  final bool hasCampaign;

  /// What a single stage is called. Null when [hasCampaign] is false.
  final StageAxis? stageAxis;

  /// Number of stages on the board (0 when [hasCampaign] is false).
  final int stageCount;

  const CoopSpec({
    this.hasCampaign = false,
    this.stageAxis,
    this.stageCount = 0,
  });
}

/// Cooperative games only. Absence from this map means the game is competitive.
const kCoopRegistry = <String, CoopSpec>{
  // The Crew: The Quest for Planet Nine — 50-mission logbook.
  'the-crew-the-quest-for-planet-nine-2019': CoopSpec(
    hasCampaign: true,
    stageAxis: StageAxis.mission,
    stageCount: 50,
  ),
  // The Crew: Mission Deep Sea — 96-mission logbook.
  'the-crew-mission-deep-sea-2021': CoopSpec(
    hasCampaign: true,
    stageAxis: StageAxis.mission,
    stageCount: 96,
  ),
  // Gloomhaven — 95-scenario campaign (flat count; branching deferred).
  'gloomhaven-2017': CoopSpec(
    hasCampaign: true,
    stageAxis: StageAxis.scenario,
    stageCount: 95,
  ),
  // Pandemic — one-shot cooperative, win/loss only, no stage board.
  'pandemic-2008': CoopSpec(),
};

/// The co-op spec for [gameId], or null when the game is competitive.
CoopSpec? coopSpecForGame(String gameId) => kCoopRegistry[gameId];

/// The co-op spec for [gameId] only when it runs a campaign board, else null.
/// Convenience for surfaces that only care about games with a stage board.
CoopSpec? campaignForGame(String gameId) {
  final spec = kCoopRegistry[gameId];
  return (spec != null && spec.hasCampaign) ? spec : null;
}
