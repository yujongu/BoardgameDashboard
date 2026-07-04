import 'package:flutter/material.dart';

import '../domain/models/game_tool.dart';
import '../lost_cities/lost_cities_calculator_screen.dart';
import '../seven_wonders/seven_wonders_calculator_screen.dart';
import '../seven_wonders_duel/seven_wonders_duel_calculator_screen.dart';
import '../terraforming_mars/terraforming_mars_calculator_screen.dart';
import '../wingspan/wingspan_calculator_screen.dart';

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
  '7-wonders-duel-2015': [
    GameTool(
      id: 'seven-wonders-duel-score-calculator',
      title: 'Score Calculator',
      description: 'Tally 7 Wonders Duel civilian-victory scores',
      icon: Icons.calculate,
      destinationBuilder: (_) => const SevenWondersDuelCalculatorScreen(),
    ),
  ],
  '7-wonders-2010': [
    GameTool(
      id: 'seven-wonders-score-calculator',
      title: 'Score Calculator',
      description: 'Tally science sets, military, coins, and card VP',
      icon: Icons.calculate,
      destinationBuilder: (_) => const SevenWondersCalculatorScreen(),
    ),
  ],
  'wingspan-2019': [
    GameTool(
      id: 'wingspan-score-calculator',
      title: 'Score Calculator',
      description: 'Sum birds, bonuses, goals, eggs, food, and tucked cards',
      icon: Icons.calculate,
      destinationBuilder: (_) => const WingspanCalculatorScreen(),
    ),
  ],
};

List<GameTool> toolsForGame(String gameId) =>
    kGameToolsRegistry[gameId] ?? const [];
