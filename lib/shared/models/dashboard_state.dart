import 'package:flutter/foundation.dart';
import 'game.dart';

class DashboardState extends ChangeNotifier {
  final List<GameStats> _trackedGames = [];

  List<GameStats> get trackedGames => List.unmodifiable(_trackedGames);

  Set<String> get trackedIds => _trackedGames.map((g) => g.game.id).toSet();

  List<Game> get availableToAdd =>
      allGames.where((g) => !trackedIds.contains(g.id)).toList();

  void addGame(Game game) {
    _trackedGames.add(GameStats(game: game, totalPlays: 0, wins: 0));
    notifyListeners();
  }

  void removeGame(String gameId) {
    _trackedGames.removeWhere((gs) => gs.game.id == gameId);
    notifyListeners();
  }
}
