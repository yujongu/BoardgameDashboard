import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_game.dart';

class GameCatalogRepository {
  GameCatalogRepository._();
  static final instance = GameCatalogRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<CatalogGame>> watchGames() {
    return _db
        .collection('boardGames')
        .orderBy('name')
        .limit(100)
        .snapshots()
        .map((qs) => qs.docs.map(_fromDoc).toList());
  }

  /// Prefix search: matches all game names that start with [query].
  Stream<List<CatalogGame>> searchGames(String query) {
    //  is a high Unicode sentinel that bounds the prefix range.
    final end = '$query\uf8ff';
    return _db
        .collection('boardGames')
        .orderBy('name')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: end)
        .limit(100)
        .snapshots()
        .map((qs) => qs.docs.map(_fromDoc).toList());
  }

  static CatalogGame _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => CatalogGame(gameId: doc.id, name: doc.data()['name'] as String);
}
