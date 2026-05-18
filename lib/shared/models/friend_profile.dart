class FriendGameStat {
  final String gameId;
  final String gameName;
  final int playCount;
  final int winCount;

  const FriendGameStat({
    required this.gameId,
    required this.gameName,
    required this.playCount,
    required this.winCount,
  });

  factory FriendGameStat.fromJson(Map<String, dynamic> json) => FriendGameStat(
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playCount: (json['playCount'] as num).toInt(),
    winCount: (json['winCount'] as num).toInt(),
  );
}

class FriendProfile {
  final String name;
  final String? photoUrl;
  final int totalGamesPlayed;
  final int totalWins;
  final DateTime? lastPlayedAt;
  final List<FriendGameStat> topGames;

  const FriendProfile({
    required this.name,
    this.photoUrl,
    required this.totalGamesPlayed,
    required this.totalWins,
    this.lastPlayedAt,
    required this.topGames,
  });

  double get winRate =>
      totalGamesPlayed == 0 ? 0.0 : totalWins / totalGamesPlayed;
}
