import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/campaign.dart';
import '../../shared/models/catalog_game.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/repositories/play_repository.dart';
import '../library/campaign_registry.dart';

class ParticipantData {
  final String name;
  final bool isWinner;
  final String? userId;
  final double? score;

  const ParticipantData({
    this.name = '',
    this.isWinner = false,
    this.userId,
    this.score,
  });

  ParticipantData copyWith({
    String? name,
    bool? isWinner,
    String? userId,
    double? score,
    bool clearScore = false,
  }) => ParticipantData(
    name: name ?? this.name,
    isWinner: isWinner ?? this.isWinner,
    userId: userId ?? this.userId,
    score: clearScore ? null : score ?? this.score,
  );
}

class AddPlayState {
  final CatalogGame? selectedGame;
  final List<ParticipantData> participants;
  final DateTime playedAt;
  final bool saving;
  final String? saveError;
  final String? currentUserId;

  // Cooperative state (null/unset for competitive games).
  final CoopSpec? coopSpec;
  final String? outcome; // 'win' | 'loss'
  final Campaign? campaign;
  final int? stage;

  const AddPlayState({
    this.selectedGame,
    this.participants = const [],
    required this.playedAt,
    this.saving = false,
    this.saveError,
    this.currentUserId,
    this.coopSpec,
    this.outcome,
    this.campaign,
    this.stage,
  });

  int get _effectiveMin => selectedGame?.minPlayers ?? 1;
  int get _effectiveMax => selectedGame?.maxPlayers ?? 99;

  bool get canAddParticipant => participants.length < _effectiveMax;

  bool get isCoop => coopSpec != null;
  bool get hasCampaign => coopSpec?.hasCampaign ?? false;

  bool get canSave {
    if (selectedGame == null) return false;
    if (participants.length < _effectiveMin) return false;
    // Switching to a game with a lower cap leaves the extra participants in
    // place, so the maximum has to be re-checked here and not only when adding.
    if (participants.length > _effectiveMax) return false;
    if (!participants.any((p) => p.name.trim().isNotEmpty)) return false;
    if (isCoop) {
      if (outcome == null) return false;
      if (hasCampaign && (campaign == null || stage == null)) return false;
      return true;
    }
    if (!participants.any((p) => p.isWinner && p.name.trim().isNotEmpty)) {
      return false;
    }
    return true;
  }

  /// Minimum players required for the selected game (1 when none selected).
  int get effectiveMinPlayers => _effectiveMin;

  /// True when a game is selected but not enough players have been added yet.
  bool get belowMinPlayers =>
      selectedGame != null && participants.length < _effectiveMin;

  /// True when a game is selected and the play holds more players than it
  /// allows — only reachable by switching to a game with a smaller maximum.
  bool get aboveMaxPlayers =>
      selectedGame != null && participants.length > _effectiveMax;

  /// Max players for the selected game, or null when none is selected / unbounded.
  int? get maxPlayers => selectedGame?.maxPlayers;

  AddPlayState copyWith({
    CatalogGame? selectedGame,
    List<ParticipantData>? participants,
    DateTime? playedAt,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
    CoopSpec? coopSpec,
    bool clearCoopSpec = false,
    String? outcome,
    bool clearOutcome = false,
    Campaign? campaign,
    bool clearCampaign = false,
    int? stage,
    bool clearStage = false,
  }) => AddPlayState(
    selectedGame: selectedGame ?? this.selectedGame,
    participants: participants ?? this.participants,
    playedAt: playedAt ?? this.playedAt,
    saving: saving ?? this.saving,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    currentUserId: currentUserId,
    coopSpec: clearCoopSpec ? null : coopSpec ?? this.coopSpec,
    outcome: clearOutcome ? null : outcome ?? this.outcome,
    campaign: clearCampaign ? null : campaign ?? this.campaign,
    stage: clearStage ? null : stage ?? this.stage,
  );
}

class AddPlayNotifier extends StateNotifier<AddPlayState> {
  AddPlayNotifier({
    String? currentUserName,
    String? currentUserId,
    PlayRepository? repo,
  }) : _repo = repo ?? PlayRepository.instance,
       super(
         AddPlayState(
           playedAt: DateTime.now(),
           currentUserId: currentUserId,
           participants: currentUserId != null
               ? [
                   ParticipantData(
                     name: currentUserName ?? '',
                     userId: currentUserId,
                   ),
                 ]
               : const [],
         ),
       );

  final PlayRepository _repo;

  void onGameSelected(CatalogGame game) {
    final spec = coopSpecForGame(game.gameId);
    state = state.copyWith(
      selectedGame: game,
      coopSpec: spec,
      clearCoopSpec: spec == null,
      clearOutcome: true,
      clearCampaign: true,
      clearStage: true,
    );
  }

  void setOutcome(String outcome) => state = state.copyWith(outcome: outcome);

  /// Selects a table and defaults the stage to its next incomplete one.
  /// Pins [campaign] and seats the play with the table's participants.
  ///
  /// A table's seats are fixed, and everyone at the table plays every session,
  /// so the participant list is taken wholesale from the campaign rather than
  /// being edited on the form.
  void setCampaign(Campaign campaign) {
    final stage = campaign.nextIncompleteStage(state.coopSpec?.stageCount ?? 1);
    state = state.copyWith(
      campaign: campaign,
      stage: stage,
      participants: [
        for (final m in campaign.participants)
          ParticipantData(name: m.name, userId: m.userId),
      ],
    );
  }

  void setStage(int stage) => state = state.copyWith(stage: stage);

  void addParticipant() {
    if (!state.canAddParticipant) return;
    state = state.copyWith(
      participants: [...state.participants, const ParticipantData()],
    );
  }

  void addParticipantWithData(String name, {String? userId}) {
    if (!state.canAddParticipant) return;
    state = state.copyWith(
      participants: [
        ...state.participants,
        ParticipantData(name: name, userId: userId),
      ],
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

  void updateParticipantScore(int index, double? score) {
    if (index < 0 || index >= state.participants.length) return;
    if (state.participants[index].score == score) return;
    final updated = List<ParticipantData>.from(state.participants);
    updated[index] = score == null
        ? updated[index].copyWith(clearScore: true)
        : updated[index].copyWith(score: score);
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
            score: p.score,
          ),
        )
        .toList();

    state = state.copyWith(saving: true, clearSaveError: true);
    try {
      final coop = state.isCoop;
      await _repo.createPlay(
        CreatePlayInput(
          gameId: state.selectedGame!.gameId,
          gameName: state.selectedGame!.name,
          playedAt: state.playedAt,
          participants: participants,
          location: (location?.trim().isNotEmpty ?? false)
              ? location!.trim()
              : null,
          notes: (notes?.trim().isNotEmpty ?? false) ? notes!.trim() : null,
          mode: coop ? PlayMode.coop : PlayMode.competitive,
          outcome: coop ? state.outcome : null,
          campaignId: coop ? state.campaign?.id : null,
          stageId: coop ? state.stage?.toString() : null,
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
      return AddPlayNotifier(
        currentUserName: name,
        currentUserId: uid,
        repo: ref.watch(playRepositoryProvider),
      );
    });
