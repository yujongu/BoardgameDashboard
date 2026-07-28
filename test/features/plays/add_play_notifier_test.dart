import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/plays/add_play_notifier.dart';
import 'package:board_game_dashboard/shared/models/catalog_game.dart';
import 'package:board_game_dashboard/shared/models/play.dart';
import 'package:board_game_dashboard/shared/repositories/play_repository.dart';

/// Fake repo whose createPlay either records the call or throws. Only
/// createPlay is exercised; everything else routes through noSuchMethod.
class _FakePlayRepo implements PlayRepository {
  _FakePlayRepo({this.throwOnCreate = false});

  final bool throwOnCreate;
  int createCalls = 0;

  @override
  Future<String> createPlay(CreatePlayInput input) async {
    createCalls++;
    if (throwOnCreate) throw Exception('boom');
    return 'play-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AddPlayNotifier', () {
    late AddPlayNotifier notifier;

    // Reusable game fixtures
    const game3to6 = CatalogGame(
      gameId: 'catan',
      name: 'Catan',
      minPlayers: 3,
      maxPlayers: 6,
    );
    const game2to2 = CatalogGame(
      gameId: 'chess',
      name: 'Chess',
      minPlayers: 2,
      maxPlayers: 2,
    );
    const game2to4 = CatalogGame(
      gameId: 'ticket',
      name: 'Ticket to Ride',
      minPlayers: 2,
      maxPlayers: 4,
    );

    setUp(() {
      // No currentUserId → starts with empty participants (no Firebase needed).
      notifier = AddPlayNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    // Local terse helper for adding named participants.
    void addNamed(String n) => notifier.addParticipantWithData(n);

    // ── initial state ────────────────────────────────────────────────────────

    test('starts with no participants and no game selected', () {
      expect(notifier.state.participants, isEmpty);
      expect(notifier.state.selectedGame, isNull);
    });

    // ── onGameSelected: sets game only ───────────────────────────────────────

    test('onGameSelected sets the game without adding participants', () {
      notifier.onGameSelected(game3to6);

      expect(notifier.state.participants, isEmpty);
      expect(notifier.state.selectedGame, game3to6);
    });

    test('onGameSelected preserves existing participants', () {
      addNamed('Alice');

      notifier.onGameSelected(game3to6);

      expect(notifier.state.participants.length, 1);
      expect(notifier.state.participants[0].name, 'Alice');
    });

    test(
      'onGameSelected does not trim participants when switching to a smaller-max game',
      () {
        notifier.onGameSelected(game3to6);
        addNamed('Alice');
        addNamed('Bob');
        addNamed('Carol');

        // Switch to a game that caps at 2; participants must be untouched.
        notifier.onGameSelected(game2to2);

        expect(notifier.state.participants.length, 3);
        expect(notifier.state.participants[0].name, 'Alice');
        expect(notifier.state.participants[1].name, 'Bob');
        expect(notifier.state.participants[2].name, 'Carol');
      },
    );

    test('preserves all existing participant data when no overflow', () {
      notifier.onGameSelected(game2to4);
      addNamed('Alice');
      addNamed('Bob');
      notifier.toggleWinner(0);

      // Switch to a different game; participant data is preserved as-is.
      notifier.onGameSelected(game3to6);

      expect(notifier.state.participants.length, 2);
      expect(notifier.state.participants[0].name, 'Alice');
      expect(notifier.state.participants[0].isWinner, isTrue);
      expect(notifier.state.participants[1].name, 'Bob');
    });

    // ── canAddParticipant / addButtonText ────────────────────────────────────

    test('canAddParticipant is false at maxPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.participants.length, 2);
      expect(notifier.state.canAddParticipant, isFalse);
    });

    test('canAddParticipant is false when at maxPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.canAddParticipant, isFalse);
    });

    test('canAddParticipant is true when below maxPlayers', () {
      notifier.onGameSelected(game3to6);

      expect(notifier.state.canAddParticipant, isTrue);
    });

    test('addParticipant is a no-op when already at maxPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      notifier.addParticipant(); // should be ignored

      expect(notifier.state.participants.length, 2);
    });

    // ── canSave / saveButtonText ─────────────────────────────────────────────

    test('canSave is false when participant count is below minPlayers', () {
      notifier.onGameSelected(game3to6);
      addNamed('Alice');
      addNamed('Bob');
      notifier.toggleWinner(
        0,
      ); // names + winner present; only count is below min

      expect(notifier.state.canSave, isFalse);
    });

    test('belowMinPlayers is true (and exposes min) when below minPlayers', () {
      notifier.onGameSelected(game3to6);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.belowMinPlayers, isTrue);
      expect(notifier.state.effectiveMinPlayers, 3);
    });

    test('belowMinPlayers is false when at or above minPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.belowMinPlayers, isFalse);
    });

    test('canSave is false when no winner is marked', () {
      notifier.onGameSelected(game2to2);
      addNamed('Alice');
      addNamed('Bob');
      // No winner toggled

      expect(notifier.state.canSave, isFalse);
    });

    test('canSave is true when conditions are met', () {
      notifier.onGameSelected(game2to2);
      addNamed('Alice');
      addNamed('Bob');
      notifier.toggleWinner(0);

      expect(notifier.state.canSave, isTrue);
    });

    // ── maximum player count (defects.md D5) ─────────────────────────────────
    //
    // canSave checked the minimum but never the maximum, and onGameSelected
    // deliberately keeps participants (see the trim test above). Switching to a
    // game with a smaller cap therefore allowed, and saved, a play with more
    // players than the game permits — a 6-player 7 Wonders Duel reached
    // Firestore with participantCount 6.

    test('canSave is false when the play exceeds the game maximum', () {
      notifier.onGameSelected(game3to6);
      addNamed('Alice');
      addNamed('Bob');
      addNamed('Carol');
      notifier.toggleWinner(0);
      expect(notifier.state.canSave, isTrue);

      // Same three players, now in a strictly 2-player game.
      notifier.onGameSelected(game2to2);

      expect(notifier.state.canSave, isFalse);
    });

    test('aboveMaxPlayers reports the overflow after a game switch', () {
      notifier.onGameSelected(game3to6);
      addNamed('Alice');
      addNamed('Bob');
      addNamed('Carol');
      expect(notifier.state.aboveMaxPlayers, isFalse);

      notifier.onGameSelected(game2to2);

      expect(notifier.state.aboveMaxPlayers, isTrue);
      expect(notifier.state.maxPlayers, 2);
      expect(notifier.state.participants.length, 3);
    });

    test('aboveMaxPlayers is false at exactly the maximum', () {
      notifier.onGameSelected(game2to2);
      addNamed('Alice');
      addNamed('Bob');

      expect(notifier.state.aboveMaxPlayers, isFalse);
      expect(notifier.state.canSave, isFalse); // no winner yet
      notifier.toggleWinner(0);
      expect(notifier.state.canSave, isTrue);
    });

    test('removing the overflow re-enables saving', () {
      notifier.onGameSelected(game3to6);
      addNamed('Alice');
      addNamed('Bob');
      addNamed('Carol');
      notifier.toggleWinner(0);
      notifier.onGameSelected(game2to2);
      expect(notifier.state.canSave, isFalse);

      notifier.removeParticipant(2);

      expect(notifier.state.aboveMaxPlayers, isFalse);
      expect(notifier.state.canSave, isTrue);
    });

    test('no game selected imposes no maximum', () {
      addNamed('Alice');
      addNamed('Bob');

      expect(notifier.state.aboveMaxPlayers, isFalse);
    });

    // ── playerCountText ──────────────────────────────────────────────────────

    test('participant count and maxPlayers reflect a game with maxPlayers', () {
      notifier.onGameSelected(game2to4);
      notifier.addParticipant();
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.participants.length, 3);
      expect(notifier.state.maxPlayers, 4);
    });

    test('maxPlayers is null when no game is selected', () {
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.participants.length, 2);
      expect(notifier.state.maxPlayers, isNull);
    });

    // ── updateParticipantScore ───────────────────────────────────────────────

    test('updateParticipantScore sets and clears a participant score', () {
      addNamed('Alice');

      notifier.updateParticipantScore(0, 42);
      expect(notifier.state.participants[0].score, 42);

      notifier.updateParticipantScore(0, null);
      expect(notifier.state.participants[0].score, isNull);
    });

    test('updateParticipantScore ignores out-of-range indices', () {
      addNamed('Alice');

      notifier.updateParticipantScore(5, 10);

      expect(notifier.state.participants.length, 1);
      expect(notifier.state.participants[0].score, isNull);
    });

    // ── pre-filled current user ──────────────────────────────────────────────

    test('always adds current user as first participant when logged in', () {
      final seeded = AddPlayNotifier(
        currentUserName: 'Joey',
        currentUserId: 'uid-123',
      );
      addTearDown(seeded.dispose);

      expect(seeded.state.participants.length, 1);
      expect(seeded.state.participants.first.name, 'Joey');
      expect(seeded.state.participants.first.userId, 'uid-123');
    });

    test(
      'adds current user row with empty name when display name is not set',
      () {
        final seeded = AddPlayNotifier(currentUserId: 'uid-123');
        addTearDown(seeded.dispose);

        expect(seeded.state.participants.length, 1);
        expect(seeded.state.participants.first.name, '');
        expect(seeded.state.participants.first.userId, 'uid-123');
      },
    );

    // ── save() — H3 error surfacing ──────────────────────────────────────────

    AddPlayNotifier saveReady(PlayRepository repo) {
      final n = AddPlayNotifier(
        currentUserName: 'Me',
        currentUserId: 'u1',
        repo: repo,
      );
      n.onGameSelected(game2to2);
      n.addParticipantWithData('Bob');
      n.toggleWinner(0); // "Me" wins → a named winner is present
      return n;
    }

    test('save() returns true and calls createPlay on success', () async {
      final repo = _FakePlayRepo();
      final n = saveReady(repo);
      addTearDown(n.dispose);
      expect(n.state.canSave, isTrue);

      final ok = await n.save();

      expect(ok, isTrue);
      expect(repo.createCalls, 1);
      expect(n.state.saveError, isNull);
    });

    test('save() returns false and surfaces saveError on failure', () async {
      final repo = _FakePlayRepo(throwOnCreate: true);
      final n = saveReady(repo);
      addTearDown(n.dispose);

      final ok = await n.save();

      expect(ok, isFalse);
      expect(n.state.saving, isFalse);
      expect(n.state.saveError, isNotNull);
    });
  });
}
