import 'package:cloud_functions/cloud_functions.dart';

import '../models/catalog_game.dart';

class GameCatalogRepository {
  GameCatalogRepository._();
  static final instance = GameCatalogRepository._();

  FirebaseFunctions get _fn => FirebaseFunctions.instance;

  Future<List<CatalogGame>> listBoardGames({
    String? search,
    int limit = 20,
  }) async {
    final result = await _fn.httpsCallable('listBoardGames').call({
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['games'] as List<dynamic>)
        .map((g) => CatalogGame.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
  }
}
