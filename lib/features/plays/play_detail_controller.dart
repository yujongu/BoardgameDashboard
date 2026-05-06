import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/play.dart';
import '../../shared/repositories/play_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class PlayDetailState {
  const PlayDetailState({
    required this.gameName,
    required this.playedAt,
    required this.participantCount,
    this.location,
    this.notes,
    this.createdBy,
    this.participants,
    this.participantsError,
  });

  factory PlayDetailState.fromSummary(PlaySummary s) => PlayDetailState(
    gameName: s.gameName,
    playedAt: s.playedAt,
    participantCount: s.participantCount,
  );

  final String gameName;
  final DateTime playedAt;
  final int participantCount;
  final String? location;
  final String? notes;
  final String? createdBy;

  /// null = still loading; non-null = loaded (may be empty)
  final List<ParticipantResult>? participants;
  final Object? participantsError;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PlayDetailNotifier extends StateNotifier<PlayDetailState> {
  PlayDetailNotifier(this._initial)
    : super(PlayDetailState.fromSummary(_initial)) {
    _listenToDoc();
    _loadParticipants();
  }

  final PlaySummary _initial;
  final _repo = PlayRepository.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  void _listenToDoc() {
    _docSub = _repo.watchPlayDoc(_initial.playId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      final ts = d['playedAt'];
      state = PlayDetailState(
        gameName: (d['gameName'] as String?) ?? state.gameName,
        playedAt: ts is Timestamp ? ts.toDate() : state.playedAt,
        participantCount:
            (d['participantCount'] as int?) ?? state.participantCount,
        location: d['location'] as String?,
        notes: d['notes'] as String?,
        createdBy: (d['createdBy'] as String?) ?? state.createdBy,
        participants: state.participants,
        participantsError: state.participantsError,
      );
    });
  }

  void _loadParticipants() {
    _repo
        .getPlay(_initial.playId)
        .then(
          (detail) {
            if (!mounted) return;
            state = PlayDetailState(
              gameName: state.gameName,
              playedAt: state.playedAt,
              participantCount: state.participantCount,
              location: state.location ?? detail.location,
              notes: state.notes ?? detail.notes,
              createdBy: state.createdBy ?? detail.createdBy,
              participants: _sorted(detail.participants),
              participantsError: null,
            );
          },
          onError: (Object e) {
            if (!mounted) return;
            state = PlayDetailState(
              gameName: state.gameName,
              playedAt: state.playedAt,
              participantCount: state.participantCount,
              location: state.location,
              notes: state.notes,
              createdBy: state.createdBy,
              participants: state.participants,
              participantsError: e,
            );
          },
        );
  }

  void retryLoadParticipants() => _loadParticipants();

  /// Builds a [PlayDetail] from current state for the edit screen.
  /// Returns null if participants haven't loaded yet.
  PlayDetail? buildCurrentPlayDetail() {
    final parts = state.participants;
    if (parts == null) return null;
    return PlayDetail(
      playId: _initial.playId,
      gameId: _initial.gameId,
      gameName: state.gameName,
      playedAt: state.playedAt,
      createdBy: state.createdBy ?? '',
      participantCount: state.participantCount,
      participants: parts,
      location: state.location,
      notes: state.notes,
    );
  }

  /// Applies [input] optimistically, commits to backend.
  /// Reverts state and returns the error if the Cloud Function fails.
  Future<Object?> applyUpdate(UpdatePlayInput input) async {
    final previous = state;
    state = PlayDetailState(
      gameName: input.gameName,
      playedAt: input.playedAt,
      participantCount: input.participants.length,
      location: state.location,
      notes: state.notes,
      createdBy: state.createdBy,
      participants: _sorted(
        input.participants
            .map(
              (p) => ParticipantResult(
                userId: p.userId,
                name: p.name,
                isWinner: p.isWinner,
                score: p.score,
              ),
            )
            .toList(),
      ),
      participantsError: null,
    );
    try {
      await _repo.updatePlay(input);
      return null;
    } catch (e) {
      if (mounted) state = previous;
      return e;
    }
  }

  /// Fires the delete CF. Call before popping the screen; the Future outlives disposal.
  Future<void> deletePlay() => _repo.deletePlay(_initial.playId);

  static List<ParticipantResult> _sorted(List<ParticipantResult> list) {
    final copy = [...list];
    if (copy.any((p) => p.rank != null)) {
      copy.sort((a, b) {
        if (a.rank == null) return 1;
        if (b.rank == null) return -1;
        return a.rank!.compareTo(b.rank!);
      });
    } else {
      copy.sort((a, b) {
        if (a.isWinner && !b.isWinner) return -1;
        if (!a.isWinner && b.isWinner) return 1;
        return a.name.compareTo(b.name);
      });
    }
    return copy;
  }

  @override
  void dispose() {
    _docSub?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final playDetailProvider = StateNotifierProvider.autoDispose
    .family<PlayDetailNotifier, PlayDetailState, PlaySummary>(
      (ref, initial) => PlayDetailNotifier(initial),
    );
