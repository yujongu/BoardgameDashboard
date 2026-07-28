import 'package:flutter/material.dart';

import '../azul/azul_calculator_screen.dart';
import '../azul_summer_pavilion/azul_summer_pavilion_calculator_screen.dart';
import '../blokus/blokus_calculator_screen.dart';
import '../calico/calico_calculator_screen.dart';
import '../cascadia/cascadia_calculator_screen.dart';
import '../castles_of_burgundy/castles_of_burgundy_calculator_screen.dart';
import '../concordia/concordia_calculator_screen.dart';
import '../domain/models/game_tool.dart';
import '../everdell/everdell_calculator_screen.dart';
import '../kingdomino/kingdomino_calculator_screen.dart';
import '../lords_of_waterdeep/lords_of_waterdeep_calculator_screen.dart';
import '../lost_cities/lost_cities_calculator_screen.dart';
import '../lost_ruins_of_arnak/lost_ruins_of_arnak_calculator_screen.dart';
import '../parks/parks_calculator_screen.dart';
import '../patchwork/patchwork_calculator_screen.dart';
import '../photosynthesis/photosynthesis_calculator_screen.dart';
import '../point_salad/point_salad_calculator_screen.dart';
import '../puerto_rico/puerto_rico_calculator_screen.dart';
import '../race_for_the_galaxy/race_for_the_galaxy_calculator_screen.dart';
import '../roll_for_the_galaxy/roll_for_the_galaxy_calculator_screen.dart';
import '../sagrada/sagrada_calculator_screen.dart';
import '../scythe/scythe_calculator_screen.dart';
import '../seven_wonders/seven_wonders_calculator_screen.dart';
import '../seven_wonders_duel/seven_wonders_duel_calculator_screen.dart';
import '../stone_age/stone_age_calculator_screen.dart';
import '../suburbia/suburbia_calculator_screen.dart';
import '../sushi_go/sushi_go_calculator_screen.dart';
import '../sushi_go_party/sushi_go_party_calculator_screen.dart';
import '../takenoko/takenoko_calculator_screen.dart';
import '../terraforming_mars/terraforming_mars_calculator_screen.dart';
import '../ticket_to_ride/ticket_to_ride_calculator_screen.dart';
import '../ticket_to_ride_europe/ticket_to_ride_europe_calculator_screen.dart';
import '../tigris_and_euphrates/tigris_and_euphrates_calculator_screen.dart';
import '../wingspan/wingspan_calculator_screen.dart';

// Keys are Firestore game document IDs.
final Map<String, List<GameTool>> kGameToolsRegistry = {
  'azul-2017': [
    GameTool(
      id: 'azul-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolAzulDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const AzulCalculatorScreen(),
    ),
  ],
  'azul-summer-pavilion-2019': [
    GameTool(
      id: 'azul-summer-pavilion-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolAzulSummerPavilionDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const AzulSummerPavilionCalculatorScreen(),
    ),
  ],
  'cascadia-2021': [
    GameTool(
      id: 'cascadia-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolCascadiaDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const CascadiaCalculatorScreen(),
    ),
  ],
  'calico-2020': [
    GameTool(
      id: 'calico-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolCalicoDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const CalicoCalculatorScreen(),
    ),
  ],
  'sagrada-2017': [
    GameTool(
      id: 'sagrada-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSagradaDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SagradaCalculatorScreen(),
    ),
  ],
  'kingdomino-2016': [
    GameTool(
      id: 'kingdomino-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolKingdominoDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const KingdominoCalculatorScreen(),
    ),
  ],
  'patchwork-2014': [
    GameTool(
      id: 'patchwork-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolPatchworkDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const PatchworkCalculatorScreen(),
    ),
  ],
  'ticket-to-ride-2004': [
    GameTool(
      id: 'ticket-to-ride-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolTicketToRideDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const TicketToRideCalculatorScreen(),
    ),
  ],
  'ticket-to-ride-europe-2005': [
    GameTool(
      id: 'ticket-to-ride-europe-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolTicketToRideEuropeDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const TicketToRideEuropeCalculatorScreen(),
    ),
  ],
  'sushi-go-2013': [
    GameTool(
      id: 'sushi-go-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSushiGoDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SushiGoCalculatorScreen(),
    ),
  ],
  'sushi-go-party-2016': [
    GameTool(
      id: 'sushi-go-party-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSushiGoPartyDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SushiGoPartyCalculatorScreen(),
    ),
  ],
  'parks-2019': [
    GameTool(
      id: 'parks-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolParksDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const ParksCalculatorScreen(),
    ),
  ],
  'everdell-2018': [
    GameTool(
      id: 'everdell-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolEverdellDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const EverdellCalculatorScreen(),
    ),
  ],
  'point-salad-2019': [
    GameTool(
      id: 'point-salad-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolPointSaladDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const PointSaladCalculatorScreen(),
    ),
  ],
  'stone-age-2008': [
    GameTool(
      id: 'stone-age-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolStoneAgeDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const StoneAgeCalculatorScreen(),
    ),
  ],
  'puerto-rico-2002': [
    GameTool(
      id: 'puerto-rico-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolPuertoRicoDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const PuertoRicoCalculatorScreen(),
    ),
  ],
  'concordia-2013': [
    GameTool(
      id: 'concordia-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolConcordiaDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const ConcordiaCalculatorScreen(),
    ),
  ],
  'the-castles-of-burgundy-2011': [
    GameTool(
      id: 'castles-of-burgundy-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolCastlesOfBurgundyDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const CastlesOfBurgundyCalculatorScreen(),
    ),
  ],
  'lords-of-waterdeep-2012': [
    GameTool(
      id: 'lords-of-waterdeep-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolLordsOfWaterdeepDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const LordsOfWaterdeepCalculatorScreen(),
    ),
  ],
  'suburbia-2012': [
    GameTool(
      id: 'suburbia-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSuburbiaDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SuburbiaCalculatorScreen(),
    ),
  ],
  'scythe-2016': [
    GameTool(
      id: 'scythe-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolScytheDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const ScytheCalculatorScreen(),
    ),
  ],
  'lost-ruins-of-arnak-2020': [
    GameTool(
      id: 'lost-ruins-of-arnak-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolLostRuinsOfArnakDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const LostRuinsOfArnakCalculatorScreen(),
    ),
  ],
  'race-for-the-galaxy-2007': [
    GameTool(
      id: 'race-for-the-galaxy-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolRaceForTheGalaxyDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const RaceForTheGalaxyCalculatorScreen(),
    ),
  ],
  'roll-for-the-galaxy-2014': [
    GameTool(
      id: 'roll-for-the-galaxy-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolRollForTheGalaxyDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const RollForTheGalaxyCalculatorScreen(),
    ),
  ],
  'tigris-and-euphrates-1997': [
    GameTool(
      id: 'tigris-and-euphrates-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolTigrisAndEuphratesDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const TigrisAndEuphratesCalculatorScreen(),
    ),
  ],
  'takenoko-2011': [
    GameTool(
      id: 'takenoko-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolTakenokoDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const TakenokoCalculatorScreen(),
    ),
  ],
  'photosynthesis-2017': [
    GameTool(
      id: 'photosynthesis-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolPhotosynthesisDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const PhotosynthesisCalculatorScreen(),
    ),
  ],
  'blokus-2000': [
    GameTool(
      id: 'blokus-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolBlokusDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const BlokusCalculatorScreen(),
    ),
  ],
  'lost-cities-1999': [
    GameTool(
      id: 'lost-cities-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolLostCitiesDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const LostCitiesCalculatorScreen(),
    ),
  ],
  'terraforming-mars-2016': [
    GameTool(
      id: 'terraforming-mars-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolTerraformingMarsDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const TerraformingMarsCalculatorScreen(),
    ),
  ],
  '7-wonders-duel-2015': [
    GameTool(
      id: 'seven-wonders-duel-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSevenWondersDuelDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SevenWondersDuelCalculatorScreen(),
    ),
  ],
  '7-wonders-2010': [
    GameTool(
      id: 'seven-wonders-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolSevenWondersDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const SevenWondersCalculatorScreen(),
    ),
  ],
  'wingspan-2019': [
    GameTool(
      id: 'wingspan-score-calculator',
      title: (s) => s.toolScoreCalculator,
      description: (s) => s.toolWingspanDesc,
      icon: Icons.calculate,
      destinationBuilder: (_) => const WingspanCalculatorScreen(),
    ),
  ],
};

List<GameTool> toolsForGame(String gameId) =>
    kGameToolsRegistry[gameId] ?? const [];
