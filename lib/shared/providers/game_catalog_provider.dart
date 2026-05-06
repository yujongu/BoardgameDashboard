import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog_game.dart';
import '../repositories/game_catalog_repository.dart';

class GameCatalogState {
  final List<CatalogGame>? games; // null = first load not yet complete
  final bool loading;
  final String? error;

  const GameCatalogState({this.games, this.loading = true, this.error});

  GameCatalogState copyWith({
    List<CatalogGame>? games,
    bool? loading,
    String? error,
  }) => GameCatalogState(
    games: games ?? this.games,
    loading: loading ?? this.loading,
    error: error ?? this.error,
  );
}

class GameCatalogNotifier extends StateNotifier<GameCatalogState> {
  GameCatalogNotifier() : super(const GameCatalogState()) {
    _subscribe(GameCatalogRepository.instance.watchGames());
  }

  StreamSubscription<List<CatalogGame>>? _sub;
  Timer? _debounce;

  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _subscribe(
        query.isEmpty
            ? GameCatalogRepository.instance.watchGames()
            : GameCatalogRepository.instance.searchGames(query),
      );
    });
  }

  void _subscribe(Stream<List<CatalogGame>> stream) {
    _sub?.cancel();
    state = state.copyWith(loading: state.games == null, error: null);
    _sub = stream.listen(
      (games) {
        if (mounted) {
          state = GameCatalogState(games: games, loading: false);
        }
      },
      onError: (Object e) {
        if (mounted) {
          state = GameCatalogState(
            games: state.games,
            loading: false,
            error: e.toString(),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final gameCatalogProvider =
    StateNotifierProvider.autoDispose<GameCatalogNotifier, GameCatalogState>(
      (ref) => GameCatalogNotifier(),
    );
