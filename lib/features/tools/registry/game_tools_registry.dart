import 'package:flutter/material.dart';

import '../domain/models/game_tool.dart';
import '../lost_cities/lost_cities_calculator_screen.dart';
import '../terraforming_mars/terraforming_mars_calculator_screen.dart';

// Keys are Firestore game document IDs.
final Map<String, List<GameTool>> kGameToolsRegistry = {
  'lost-cities-1999': [
    GameTool(
      id: 'lost-cities-score-calculator',
      title: 'Score Calculator',
      description: 'Calculate Lost Cities scores quickly',
      icon: Icons.calculate,
      destinationBuilder: (_) => const LostCitiesCalculatorScreen(),
    ),
  ],
  'terraforming-mars-2016': [
    GameTool(
      id: 'terraforming-mars-score-calculator',
      title: 'Score Calculator',
      description: 'Tally TR, milestones, awards, and card VP',
      icon: Icons.calculate,
      destinationBuilder: (_) => const TerraformingMarsCalculatorScreen(),
    ),
  ],
};

List<GameTool> toolsForGame(String gameId) =>
    kGameToolsRegistry[gameId] ?? const [];
