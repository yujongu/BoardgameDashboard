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
      // No currentUserName → starts with empty participants (no Firebase needed).
      notifier = AddPlayNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    // ── initial state ────────────────────────────────────────────────────────

    test('starts with no participants and no game selected', () {
      expect(notifier.state.participants, isEmpty);
      expect(notifier.state.selectedGame, isNull);
    });

    // ── onGameSelected: auto-add minPlayers ──────────────────────────────────

    test('auto-adds minPlayers empty slots on first game selection', () {
      notifier.onGameSelected(game3to6);

      expect(notifier.state.participants.length, 3);
      expect(notifier.state.selectedGame, game3to6);
      // Auto-added slots are empty
      expect(notifier.state.participants.every((p) => p.name.isEmpty), isTrue);
    });

    test(
      'does not overwrite existing participants when auto-adding to min',
      () {
        // Start with one named participant, then select game requiring 3
        notifier.addParticipant();
        notifier.updateParticipantName(0, 'Alice');

        notifier.onGameSelected(game3to6);

        expect(notifier.state.participants.length, 3);
        expect(notifier.state.participants[0].name, 'Alice');
        expect(notifier.state.participants[1].name, '');
        expect(notifier.state.participants[2].name, '');
      },
    );

    // ── onGameSelected: remove overflow participants ──────────────────────────

    test('removes overflow participants from the end on game change', () {
      // Seed 5 named participants via a permissive game
      notifier.onGameSelected(game3to6); // auto-adds 3
      notifier.addParticipant(); // 4
      notifier.addParticipant(); // 5
      notifier.updateParticipantName(0, 'Alice');
      notifier.updateParticipantName(1, 'Bob');
      notifier.updateParticipantName(2, 'Carol');
      notifier.updateParticipantName(3, 'Dave');
      notifier.updateParticipantName(4, 'Eve');

      // Switch to a game that caps at 2
      notifier.onGameSelected(game2to2);

      expect(notifier.state.participants.length, 2);
      expect(notifier.state.participants[0].name, 'Alice');
      expect(notifier.state.participants[1].name, 'Bob');
    });

    test(
      'only removes from the end, never reorders remaining participants',
      () {
        notifier.onGameSelected(game3to6);
        notifier.updateParticipantName(0, 'First');
        notifier.updateParticipantName(1, 'Second');
        notifier.updateParticipantName(2, 'Third');

        // Trim to max=2 (Chess)
        notifier.onGameSelected(game2to2);

        expect(notifier.state.participants[0].name, 'First');
        expect(notifier.state.participants[1].name, 'Second');
      },
    );

    // ── onGameSelected: preserve data without overflow ───────────────────────

    test('preserves all existing participant data when no overflow', () {
      notifier.onGameSelected(game2to4);
      notifier.updateParticipantName(0, 'Alice');
      notifier.updateParticipantName(1, 'Bob');
      notifier.toggleWinner(0);

      // Switch to a different game with same min (2)
      notifier.onGameSelected(game3to6); // min=3, adds one empty slot

      expect(notifier.state.participants[0].name, 'Alice');
      expect(notifier.state.participants[0].isWinner, isTrue);
      expect(notifier.state.participants[1].name, 'Bob');
      expect(notifier.state.participants[2].name, '');
      expect(notifier.state.participants.length, 3);
    });

    // ── canAddParticipant / addButtonText ────────────────────────────────────

    test('canAddParticipant is false at maxPlayers', () {
      notifier.onGameSelected(game2to2); // auto-adds 2; max is 2

      expect(notifier.state.participants.length, 2);
      expect(notifier.state.canAddParticipant, isFalse);
    });

    test('addButtonText is "Max players added" when at maxPlayers', () {
      notifier.onGameSelected(game2to2);

      expect(notifier.state.addButtonText, 'Max players added');
    });

    test('addButtonText is "+ Add Participant" when below maxPlayers', () {
      notifier.onGameSelected(game3to6);

      expect(notifier.state.canAddParticipant, isTrue);
      expect(notifier.state.addButtonText, '+ Add Participant');
    });

    test('addParticipant is a no-op when already at maxPlayers', () {
      notifier.onGameSelected(game2to2); // 2 participants, max=2

      notifier.addParticipant(); // should be ignored

      expect(notifier.state.participants.length, 2);
    });

    // ── canSave / saveButtonText ─────────────────────────────────────────────

    test('canSave is false when participant count is below minPlayers', () {
      notifier.onGameSelected(game3to6);
      notifier.removeParticipant(2); // down to 2, below min=3

      expect(notifier.state.canSave, isFalse);
    });

    test('saveButtonText shows minimum count when below minPlayers', () {
      notifier.onGameSelected(game3to6);
      notifier.removeParticipant(2); // 2 participants, min=3

      expect(notifier.state.saveButtonText, 'Minimum 3 players needed');
    });

    test('saveButtonText is "Save Play" when at or above minPlayers', () {
      notifier.onGameSelected(game2to2);
      // Still 2 participants; min=2 is satisfied

      expect(notifier.state.saveButtonText, 'Save Play');
    });

    test('canSave is false when no winner is marked', () {
      notifier.onGameSelected(game2to2);
      notifier.updateParticipantName(0, 'Alice');
      notifier.updateParticipantName(1, 'Bob');
      // No winner toggled

      expect(notifier.state.canSave, isFalse);
    });

    test('canSave is true when conditions are met', () {
      notifier.onGameSelected(game2to2);
      notifier.updateParticipantName(0, 'Alice');
      notifier.updateParticipantName(1, 'Bob');
      notifier.toggleWinner(0);

      expect(notifier.state.canSave, isTrue);
    });

    // ── playerCountText ──────────────────────────────────────────────────────

    test('playerCountText shows count and max when game has maxPlayers', () {
      notifier.onGameSelected(game2to4);
      notifier.addParticipant(); // 3 participants

      expect(notifier.state.playerCountText, 'Players: 3 / 4');
    });

    test('playerCountText shows only count when no game is selected', () {
      notifier.addParticipant();
      notifier.addParticipant();

      expect(notifier.state.playerCountText, 'Players: 2');
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
