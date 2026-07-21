import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog_game.dart';
import '../repositories/game_catalog_repository.dart';
import 'repository_providers.dart';

class GameCatalogState {
  /// null while the initial preload has not yet completed.
  final List<CatalogGame>? games;

  /// True only during the one-time preload on open. Triggers the full-screen
  /// spinner in the picker sheet.
  final bool loading;

  /// True while a remote Firestore fetch is in flight for the current query.
  /// Local results are already visible when this is true, so the UI only
  /// needs to show a small inline indicator — not a blocking spinner.
  final bool remoteLoading;

  final String? error;

  const GameCatalogState({
    this.games,
    this.loading = true,
    this.remoteLoading = false,
    this.error,
  });

  GameCatalogState copyWith({
    List<CatalogGame>? games,
    bool? loading,
    bool? remoteLoading,
    String? error,
  }) => GameCatalogState(
    games: games ?? this.games,
    loading: loading ?? this.loading,
    remoteLoading: remoteLoading ?? this.remoteLoading,
    error: error ?? this.error,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hybrid search strategy
// ─────────────────────────────────────────────────────────────────────────────
//
// Why hybrid:
//   Firestore can only do prefix range queries (`name_lower >= q`) — it cannot
//   do substring or full-text search. Storing ~250 games in memory costs a
//   single read on open and enables instant, case-insensitive SUBSTRING search
//   with zero latency for the common case (user browses or types a short query).
//
// Decision boundary (query.length < 4 → local only):
//   Short queries match many games in the local cache, so a Firestore round-
//   trip adds cost with little benefit. At 4+ characters the local cache may
//   not cover every matching game (catalog has more than 250 entries), so the
//   remote prefix query fills the gap.
// ─────────────────────────────────────────────────────────────────────────────

class GameCatalogNotifier extends StateNotifier<GameCatalogState> {
  GameCatalogNotifier(this._repo) : super(const GameCatalogState()) {
    _preload();
  }

  final GameCatalogRepository _repo;
  List<CatalogGame> _allGames = [];
  Timer? _debounce;

  // Tracks the most recent query passed to _doSearch so stale async responses
  // from superseded queries are discarded.
  String _lastQuery = '';

  // ── Preload ────────────────────────────────────────────────────────────────

  Future<void> _preload() async {
    try {
      _allGames = await _repo.fetchInitialGames();
      if (!mounted) return;
      // If the user typed while loading, apply that query to the fresh data
      // rather than showing the full unfiltered list.
      final toShow = _lastQuery.isEmpty ? _allGames : _localSearch(_lastQuery);
      state = GameCatalogState(games: toShow, loading: false);
    } catch (e) {
      if (mounted) {
        state = GameCatalogState(
          games: const [],
          loading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Re-runs the full preload. Called by the UI retry button on error.
  void reload() {
    _allGames = [];
    _lastQuery = '';
    state = const GameCatalogState();
    _preload();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _doSearch(query),
    );
  }

  Future<void> _doSearch(String query) async {
    _lastQuery = query;

    if (query.isEmpty) {
      if (mounted) {
        state = GameCatalogState(games: _allGames, loading: false);
      }
      return;
    }

    // Preload is still running — _preload() will apply _lastQuery once data
    // arrives. Don't overwrite the loading state or show empty results here.
    if (state.loading) return;

    final local = _localSearch(query);

    // Short queries are handled entirely by the in-memory cache. The 250-game
    // preload covers enough of the catalog that a Firestore call adds no value
    // while doubling read costs for every keystroke.
    if (query.length < 4) {
      if (mounted) state = state.copyWith(games: local, remoteLoading: false);
      return;
    }

    // Publish local hits immediately so the list never goes blank.
    if (mounted) state = state.copyWith(games: local, remoteLoading: true);

    try {
      final remote = await _repo.searchRemote(query);
      // Discard if the user has already typed something newer.
      if (mounted && _lastQuery == query) {
        state = state.copyWith(
          games: _merge(local, remote),
          remoteLoading: false,
        );
      }
    } catch (_) {
      // Remote failed — local results remain visible; just hide the spinner.
      if (mounted && _lastQuery == query) {
        state = state.copyWith(remoteLoading: false);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Case-insensitive substring search over the in-memory cache.
  List<CatalogGame> _localSearch(String query) {
    final q = query.toLowerCase();
    return _allGames.where((g) => g.nameLower.contains(q)).toList();
  }

  /// Combines local and remote results, deduplicating by gameId.
  /// Local entries appear first to preserve their instant-result order.
  List<CatalogGame> _merge(List<CatalogGame> local, List<CatalogGame> remote) {
    final seen = <String>{};
    final result = <CatalogGame>[];
    for (final g in local) {
      if (seen.add(g.gameId)) result.add(g);
    }
    for (final g in remote) {
      if (seen.add(g.gameId)) result.add(g);
    }
    return result;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final gameCatalogProvider =
    StateNotifierProvider.autoDispose<GameCatalogNotifier, GameCatalogState>(
      (ref) => GameCatalogNotifier(ref.watch(gameCatalogRepositoryProvider)),
    );
