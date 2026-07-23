// End-to-end UI test. Run against the Firebase Emulator Suite so it never
// touches production:
//
//   1. cd functions && npm run build
//   2. firebase emulators:start --only auth,functions,firestore
//      (Auth :9099, Functions :5001, Firestore :8080 — see main.dart)
//   3. flutter test integration_test/app_test.dart \
//        --dart-define=USE_EMULATORS=true \
//        [--dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... ...]
//
// Credentials come from --dart-define; the defaults below are throwaway
// accounts created in the Auth emulator, so no real credentials live in source.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:board_game_dashboard/main.dart' as app;

const _mainEmail = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'testmain@gameshelf.test',
);
const _mainPassword = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: 'TestPass1!',
);
const _mainDisplayName = 'Test User';

const _user2Email = String.fromEnvironment(
  'TEST_EMAIL2',
  defaultValue: 'testuser2@gameshelf.test',
);
const _user2Password = String.fromEnvironment(
  'TEST_PASSWORD2',
  defaultValue: 'TestPass2!',
);
const _user2DisplayName = 'Test User Two';

// Generous settle timeout for Firebase round-trips.
const _settle = Duration(seconds: 6);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Gameshelf full test suite', (tester) async {
    app.main();
    await tester.pumpAndSettle(_settle);

    // If Firebase persisted a previous session, sign out first so we start
    // from the login screen consistently.
    if (find.text('HOME').evaluate().isNotEmpty ||
        find.byKey(const Key('profileAvatarBtn')).evaluate().isNotEmpty) {
      await _signOut(tester);
      await tester.pumpAndSettle(_settle);
    }

    // ─── SETUP: Create testuser2 ─────────────────────────────────────────────
    // Needed for TC-08 (Friends search). Idempotent — skips if already exists.
    await _registerOrSkip(
      tester,
      _user2Email,
      _user2Password,
      _user2DisplayName,
    );
    await tester.pumpAndSettle(_settle);
    await _signOut(tester);
    await tester.pumpAndSettle(_settle);

    // ─── TC-01: Login ────────────────────────────────────────────────────────
    await _signInOrRegister(
      tester,
      _mainEmail,
      _mainPassword,
      _mainDisplayName,
    );
    await tester.pumpAndSettle(_settle);
    expect(find.text('HOME'), findsOneWidget);

    // ─── TC-02: Home Screen State ────────────────────────────────────────────
    expect(find.text('PLAYS'), findsOneWidget);
    expect(find.text('WINS'), findsOneWidget);
    expect(find.text('WIN RATE'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('Recent Plays'), findsOneWidget);

    // ─── TC-03: Add a Play Session ───────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(_settle);

    // Pick the first game from the game picker.
    await tester.tap(find.text('Select a game…'));
    await tester.pumpAndSettle(_settle);

    final gameList = find.byType(ListView);
    expect(gameList, findsOneWidget);
    final firstGameTextFinder = find
        .descendant(of: gameList, matching: find.byType(Text))
        .first;
    final gameName =
        (tester.widget<Text>(firstGameTextFinder)).data ?? 'Unknown';
    await tester.tap(firstGameTextFinder);
    await tester.pumpAndSettle();

    // Mark current user as winner.
    await tester.tap(find.byIcon(Icons.emoji_events_outlined).first);
    await tester.pumpAndSettle();

    // Add a guest participant to satisfy minPlayers ≥ 2 for most games.
    await tester.tap(find.text('+ Add Participant'));
    await tester.pumpAndSettle();

    final guestSearchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Search friends or add guest…',
    );
    await tester.enterText(guestSearchField, 'Player 2');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap the "Add guest 'Player 2'" row.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Add guest'),
      ),
    );
    await tester.pumpAndSettle();

    // Close the participant picker sheet.
    final NavigatorState navigator = tester.state(find.byType(Navigator).first);
    navigator.pop();
    await tester.pumpAndSettle();

    // Enter a note.
    final notesField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Notes (optional)',
    );
    await tester.enterText(notesField, 'Integration test note');
    await tester.pumpAndSettle();

    // Save the play.
    await tester.tap(find.text('Save Play'));
    await tester.pumpAndSettle(_settle);

    // Verify play appears on home screen.
    expect(find.text(gameName), findsWidgets);

    // ─── TC-04: Library Tab ──────────────────────────────────────────────────
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle(_settle);

    expect(find.text(gameName), findsWidgets);

    // Tap the game card to open game detail.
    await tester.tap(find.text(gameName).first);
    await tester.pumpAndSettle(_settle);

    expect(find.text('Play History'), findsOneWidget);

    // Navigate back to home.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle(_settle);

    // ─── TC-05: Play Detail — Edit ───────────────────────────────────────────
    await tester.tap(find.text(gameName).first);
    await tester.pumpAndSettle(_settle);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle(_settle);

    expect(find.text('EDIT PLAY'), findsOneWidget);

    // Save without changes to verify the round-trip works.
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle(_settle);

    expect(find.byTooltip('Delete'), findsOneWidget);

    // ─── TC-06: Play Detail — Delete ────────────────────────────────────────
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this play?'), findsOneWidget);
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle(_settle);

    // Back on home — stats row still visible.
    expect(find.text('PLAYS'), findsOneWidget);

    // ─── TC-07: Profile — Edit Display Name ─────────────────────────────────
    await tester.tap(find.byKey(const Key('profileAvatarBtn')));
    await tester.pumpAndSettle(_settle);

    expect(find.text('PROFILE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit display name'), findsOneWidget);

    final nameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Test User Updated');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(_settle);

    expect(find.text('Test User Updated'), findsOneWidget);

    // Restore original name.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      _mainDisplayName,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(_settle);

    // ─── TC-08: Friends — Search & Add ──────────────────────────────────────
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle(_settle);

    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == 'Search to add friends…',
    );
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, _user2DisplayName);
    // Wait for debounce (300ms) + Firestore round-trip.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(_settle);

    // Tap ADD if a result appears.
    final addButton = find.text('ADD');
    if (addButton.evaluate().isNotEmpty) {
      await tester.tap(addButton.first);
      await tester.pumpAndSettle(_settle);
    }

    // Navigate back to profile.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // ─── TC-09: Sign Out & Sign Back In ─────────────────────────────────────
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle(_settle);

    expect(find.text('Gameshelf'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);

    await _signIn(tester, _mainEmail, _mainPassword);
    await tester.pumpAndSettle(_settle);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Recent Plays'), findsOneWidget);
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Signs in using email/password. Switches from register mode if needed.
Future<void> _signIn(WidgetTester tester, String email, String password) async {
  // If "Create Account" is visible we're in register mode — toggle back.
  if (find
      .widgetWithText(ElevatedButton, 'Create Account')
      .evaluate()
      .isNotEmpty) {
    await tester.tap(find.text('Sign In')); // the toggle TextButton
    await tester.pumpAndSettle();
  }

  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

/// Signs in, registering and completing profile setup the first time.
Future<void> _signInOrRegister(
  WidgetTester tester,
  String email,
  String password,
  String displayName,
) async {
  await _signIn(tester, email, password);

  // Profile setup appears only for brand-new accounts.
  if (find.text('What should we call you?').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextFormField).first, displayName);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }
}

/// Registers a new account, or signs in if the account already exists.
Future<void> _registerOrSkip(
  WidgetTester tester,
  String email,
  String password,
  String displayName,
) async {
  // Switch to register mode.
  await tester.tap(find.text('Register'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Create Account'));
  await tester.pumpAndSettle(const Duration(seconds: 8));

  // Account already exists — sign in instead.
  if (find
      .text('An account with this email already exists.')
      .evaluate()
      .isNotEmpty) {
    await tester.tap(find.text('Sign In')); // toggle back to sign-in mode
    await tester.pumpAndSettle();
    await _signIn(tester, email, password);
    await tester.pumpAndSettle(const Duration(seconds: 6));
    return;
  }

  // New account — complete profile setup if shown.
  if (find.text('What should we call you?').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextFormField).first, displayName);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }
}

Future<void> _signOut(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profileAvatarBtn')));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await tester.tap(find.text('Sign Out'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}
