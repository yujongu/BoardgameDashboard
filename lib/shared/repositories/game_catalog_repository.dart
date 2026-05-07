import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_game.dart';

class GameCatalogRepository {
  GameCatalogRepository._();
  static final instance = GameCatalogRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Loads the first 250 games into the local cache used for instant search.
  /// One-shot Future — no stream — so the notifier pays one read on open and
  /// holds results in memory for the session.
  Future<List<CatalogGame>> fetchInitialGames() async {
    final qs = await _db
        .collection('boardGames')
        .orderBy('name')
        .limit(250)
        .get();
    return qs.docs.map(_fromDoc).toList();
  }

  /// Prefix search against the `name_lower` field for queries ≥ 4 characters.
  ///
  /// Why prefix-only: Firestore range queries (`>=` / `<=`) can only match
  /// from the start of a string, not arbitrary substrings. True substring
  /// search requires a third-party search service (Algolia, Typesense, etc.).
  ///
  /// Why `name_lower`: Firestore has no case-folding, so we store a lowercase
  /// copy of every game name and always lower-case the query before querying.
  Future<List<CatalogGame>> searchRemote(String query) async {
    final q = query.toLowerCase();
    final end = '$q'; //  is a high Unicode sentinel bounding the prefix
    final qs = await _db
        .collection('boardGames')
        .orderBy('name_lower')
        .where('name_lower', isGreaterThanOrEqualTo: q)
        .where('name_lower', isLessThanOrEqualTo: end)
        .limit(20)
        .get();
    return qs.docs.map(_fromDoc).toList();
  }

  static CatalogGame _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return CatalogGame(
      gameId: doc.id,
      name: data['name'] as String,
      // Fall back to computing nameLower if the field is absent (legacy docs).
      nameLower: data['name_lower'] as String?,
      minPlayers: (data['minPlayers'] as num?)?.toInt(),
      maxPlayers: (data['maxPlayers'] as num?)?.toInt(),
    );
  }
}
