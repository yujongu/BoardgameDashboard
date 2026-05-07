import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/catalog_game.dart';
import '../../shared/models/play.dart';
import '../../shared/repositories/play_repository.dart';

class ParticipantData {
  final String name;
  final bool isWinner;
  final String? userId;

  const ParticipantData({this.name = '', this.isWinner = false, this.userId});

  ParticipantData copyWith({String? name, bool? isWinner, String? userId}) =>
      ParticipantData(
        name: name ?? this.name,
        isWinner: isWinner ?? this.isWinner,
        userId: userId ?? this.userId,
      );
}

class AddPlayState {
  final CatalogGame? selectedGame;
  final List<ParticipantData> participants;
  final DateTime playedAt;
  final bool saving;
  final String? saveError;

  const AddPlayState({
    this.selectedGame,
    this.participants = const [],
    required this.playedAt,
    this.saving = false,
    this.saveError,
  });

  int get _effectiveMin => selectedGame?.minPlayers ?? 1;
  int get _effectiveMax => selectedGame?.maxPlayers ?? 99;

  bool get canAddParticipant => participants.length < _effectiveMax;

  bool get canSave {
    if (selectedGame == null) return false;
    if (participants.length < _effectiveMin) return false;
    if (!participants.any((p) => p.name.trim().isNotEmpty)) return false;
    if (!participants.any((p) => p.isWinner && p.name.trim().isNotEmpty)) {
      return false;
    }
    return true;
  }

  String get saveButtonText {
    if (selectedGame != null && participants.length < _effectiveMin) {
      return 'Minimum $_effectiveMin players needed';
    }
    return 'Save Play';
  }

  String get addButtonText =>
      canAddParticipant ? '+ Add Participant' : 'Max players added';

  String get playerCountText {
    final max = selectedGame?.maxPlayers;
    if (max != null) return 'Players: ${participants.length} / $max';
    return 'Players: ${participants.length}';
  }

  AddPlayState copyWith({
    CatalogGame? selectedGame,
    List<ParticipantData>? participants,
    DateTime? playedAt,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
  }) => AddPlayState(
    selectedGame: selectedGame ?? this.selectedGame,
    participants: participants ?? this.participants,
    playedAt: playedAt ?? this.playedAt,
    saving: saving ?? this.saving,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
  );
}

class AddPlayNotifier extends StateNotifier<AddPlayState> {
  AddPlayNotifier({String? currentUserName, String? currentUserId})
    : super(AddPlayState(playedAt: DateTime.now())) {
    if (currentUserId != null) {
      state = state.copyWith(
        participants: [
          ParticipantData(name: currentUserName ?? '', userId: currentUserId),
        ],
      );
    }
  }

  void onGameSelected(CatalogGame game) {
    final min = game.minPlayers ?? 1;
    final max = game.maxPlayers ?? 99;
    var participants = List<ParticipantData>.from(state.participants);

    while (participants.length > max) {
      participants.removeLast();
    }
    while (participants.length < min) {
      participants.add(const ParticipantData());
    }

    state = state.copyWith(selectedGame: game, participants: participants);
  }

  void addParticipant() {
    if (!state.canAddParticipant) return;
    state = state.copyWith(
      participants: [...state.participants, const ParticipantData()],
    );
  }

  void removeParticipant(int index) {
    if (index < 0 || index >= state.participants.length) return;
    final updated = List<ParticipantData>.from(state.participants)
      ..removeAt(index);
    state = state.copyWith(participants: updated);
  }

  void toggleWinner(int index) {
    if (index < 0 || index >= state.participants.length) return;
    final updated = List<ParticipantData>.from(state.participants);
    updated[index] = updated[index].copyWith(
      isWinner: !updated[index].isWinner,
    );
    state = state.copyWith(participants: updated);
  }

  void updateParticipantName(int index, String name) {
    if (index < 0 || index >= state.participants.length) return;
    if (state.participants[index].name == name) return;
    final updated = List<ParticipantData>.from(state.participants);
    updated[index] = updated[index].copyWith(name: name);
    state = state.copyWith(participants: updated);
  }

  void setPlayedAt(DateTime date) => state = state.copyWith(playedAt: date);

  Future<bool> save({String? location, String? notes}) async {
    if (!state.canSave) return false;

    final participants = state.participants
        .where((p) => p.name.trim().isNotEmpty)
        .map(
          (p) => ParticipantInput(
            userId: p.userId,
            name: p.name.trim(),
            isWinner: p.isWinner,
          ),
        )
        .toList();

    state = state.copyWith(saving: true, clearSaveError: true);
    try {
      await PlayRepository.instance.createPlay(
        CreatePlayInput(
          gameId: state.selectedGame!.gameId,
          gameName: state.selectedGame!.name,
          playedAt: state.playedAt,
          participants: participants,
          location: (location?.trim().isNotEmpty ?? false)
              ? location!.trim()
              : null,
          notes: (notes?.trim().isNotEmpty ?? false) ? notes!.trim() : null,
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(saving: false, saveError: e.toString());
      }
      return false;
    }
  }
}

final addPlayProvider =
    StateNotifierProvider.autoDispose<AddPlayNotifier, AddPlayState>((ref) {
      // Firebase lookup stays in the provider to keep the notifier testable.
      String? name;
      String? uid;
      try {
        final user = FirebaseAuth.instance.currentUser;
        name = user?.displayName;
        uid = user?.uid;
      } catch (_) {}
      return AddPlayNotifier(currentUserName: name, currentUserId: uid);
    });
