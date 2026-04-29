class Game {
  final String id;
  final String name;
  final String category;
  final String imagePath;

  const Game({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
  });
}

class GameStats {
  final Game game;
  final int totalPlays;
  final int wins;

  const GameStats({
    required this.game,
    required this.totalPlays,
    required this.wins,
  });

  double get winRate => totalPlays == 0 ? 0 : wins / totalPlays;
  int get winPercent => (winRate * 100).round();
}

final List<Game> allGames = [
  const Game(
    id: 'terra_mystica',
    name: 'Terra Mystica',
    category: 'Strategy · Fantasy',
    imagePath: '',
  ),
  const Game(
    id: 'gloomhaven',
    name: 'Gloomhaven',
    category: 'Dungeon Crawler · Adventure',
    imagePath: '',
  ),
  const Game(
    id: 'wingspan',
    name: 'Wingspan',
    category: 'Engine Builder · Nature',
    imagePath: '',
  ),
  const Game(
    id: 'brass_birmingham',
    name: 'Brass: Birmingham',
    category: 'Industrial Strategy · 1870 Era',
    imagePath: '',
  ),
  const Game(
    id: 'catan',
    name: 'Catan',
    category: 'Resource Management · Classic',
    imagePath: '',
  ),
  const Game(
    id: 'ticket_to_ride',
    name: 'Ticket to Ride',
    category: 'Network Building · Family',
    imagePath: '',
  ),
  const Game(
    id: 'pandemic',
    name: 'Pandemic',
    category: 'Co-op · Medical',
    imagePath: '',
  ),
  const Game(
    id: 'azul',
    name: 'Azul',
    category: 'Tile Drafting · Abstract',
    imagePath: '',
  ),
  const Game(
    id: 'splendor',
    name: 'Splendor',
    category: 'Engine Builder · Renaissance',
    imagePath: '',
  ),
  const Game(
    id: '7_wonders',
    name: '7 Wonders',
    category: 'Card Drafting · Ancient',
    imagePath: '',
  ),
  const Game(
    id: 'viticulture',
    name: 'Viticulture',
    category: 'Worker Placement · Wine',
    imagePath: '',
  ),
  const Game(
    id: 'everdell',
    name: 'Everdell',
    category: 'Worker Placement · Fantasy',
    imagePath: '',
  ),
  const Game(
    id: 'lost_cities',
    name: 'Lost Cities',
    category: 'Card Game · Two-Player',
    imagePath: '',
  ),
  const Game(
    id: 'splendor_duel',
    name: 'Splendor Duel',
    category: 'Engine Builder · Two-Player',
    imagePath: '',
  ),
  const Game(
    id: '7_wonders_duel',
    name: '7 Wonders Duel',
    category: 'Card Drafting · Two-Player',
    imagePath: '',
  ),
  const Game(
    id: 'the_crew_planet_nine',
    name: 'The Crew: The Quest for Planet Nine',
    category: 'Co-op · Trick-Taking',
    imagePath: '',
  ),
];
