class CatalogGame {
  final String gameId;
  final String name;
  final int? minPlayers;
  final int? maxPlayers;

  // Stored lowercase value read from the Firestore `name_lower` field.
  // Null when the document predates the field or is constructed in tests
  // without providing it; the getter falls back to name.toLowerCase() in
  // that case so all search code can call .nameLower unconditionally.
  final String? _nameLower;

  /// Lowercase name used for local substring search. All Firestore documents
  /// MUST store this as `name_lower = name.toLowerCase()` so that server-side
  /// prefix queries can work case-insensitively.
  String get nameLower => _nameLower ?? name.toLowerCase();

  const CatalogGame({
    required this.gameId,
    required this.name,
    String? nameLower,
    this.minPlayers,
    this.maxPlayers,
  }) : _nameLower = nameLower;

  factory CatalogGame.fromJson(Map<String, dynamic> json) => CatalogGame(
    gameId: json['gameId'] as String,
    name: json['name'] as String,
    nameLower: json['name_lower'] as String?,
    minPlayers: (json['minPlayers'] as num?)?.toInt(),
    maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
  );
}
