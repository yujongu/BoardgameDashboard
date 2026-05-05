class CatalogGame {
  final String gameId;
  final String name;

  const CatalogGame({required this.gameId, required this.name});

  factory CatalogGame.fromJson(Map<String, dynamic> json) => CatalogGame(
    gameId: json['gameId'] as String,
    name: json['name'] as String,
  );
}
