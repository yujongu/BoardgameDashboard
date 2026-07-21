import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/plays/add_play_notifier.dart';
import 'package:board_game_dashboard/shared/models/catalog_game.dart';

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

    test('addButtonText is "Max players added" when at maxPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.addButtonText, 'Max players added');
    });

    test('addButtonText is "+ Add Participant" when below maxPlayers', () {
      notifier.onGameSelected(game3to6);

      expect(notifier.state.canAddParticipant, isTrue);
      expect(notifier.state.addButtonText, '+ Add Participant');
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

    test('saveButtonText shows minimum count when below minPlayers', () {
      notifier.onGameSelected(game3to6);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.saveButtonText, 'Minimum 3 players needed');
    });

    test('saveButtonText is "Save Play" when at or above minPlayers', () {
      notifier.onGameSelected(game2to2);
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.saveButtonText, 'Save Play');
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

    // ── playerCountText ──────────────────────────────────────────────────────

    test('playerCountText shows count and max when game has maxPlayers', () {
      notifier.onGameSelected(game2to4);
      notifier.addParticipant();
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.playerCountText, 'Players: 3 / 4');
    });

    test('playerCountText shows only count when no game is selected', () {
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.playerCountText, 'Players: 2');
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
  });
}
