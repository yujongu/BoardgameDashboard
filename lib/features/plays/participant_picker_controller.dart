import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/friend.dart';
import '../../shared/repositories/friend_repository.dart';

class PickerSearchState {
  final String query;
  final bool loadingSearch;
  final List<UserSearchResult> searchResults;

  const PickerSearchState({
    this.query = '',
    this.loadingSearch = false,
    this.searchResults = const [],
  });

  PickerSearchState copyWith({
    String? query,
    bool? loadingSearch,
    List<UserSearchResult>? searchResults,
  }) => PickerSearchState(
    query: query ?? this.query,
    loadingSearch: loadingSearch ?? this.loadingSearch,
    searchResults: searchResults ?? this.searchResults,
  );
}

class PickerSearchNotifier extends StateNotifier<PickerSearchState> {
  PickerSearchNotifier() : super(const PickerSearchState());

  Timer? _debounce;

  void setQuery(String raw) {
    if (raw == state.query) return;
    final trimmed = raw.trim();
    state = state.copyWith(
      query: raw,
      loadingSearch: trimmed.isNotEmpty,
      // Keep stale results visible while the user types; clear only on empty.
      searchResults: trimmed.isEmpty ? [] : state.searchResults,
    );
    _debounce?.cancel();
    if (trimmed.isEmpty) return;
    // Capture at schedule-time so the async callback can discard stale results.
    final expectedQuery = trimmed;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await FriendRepository.instance.searchUsers(
          expectedQuery,
        );
        if (mounted && state.query.trim() == expectedQuery) {
          state = state.copyWith(searchResults: results, loadingSearch: false);
        }
      } catch (_) {
        // Clear spinner on error; guest-add is still available.
        if (mounted && state.query.trim() == expectedQuery) {
          state = state.copyWith(loadingSearch: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final participantPickerProvider =
    StateNotifierProvider.autoDispose<PickerSearchNotifier, PickerSearchState>(
      (_) => PickerSearchNotifier(),
    );
