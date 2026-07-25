// End-to-end test for cooperative play logging + campaign advance.
// Run against the Firebase Emulator Suite (never touches production):
//
//   1. cd functions && npm run build
//   2. firebase emulators:start --only auth,functions,firestore
//   3. FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//        node functions/seed-board-games.js functions/board-games-seed.json
//   4. flutter test integration_test/coop_test.dart \
//        -d <ios-sim-id> --dart-define=USE_EMULATORS=true
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:board_game_dashboard/main.dart' as app;

const _email = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'testmain@gameshelf.test',
);
const _password = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: 'TestPass1!',
);
const _displayName = 'Test User';

const _crew = 'The Crew: The Quest for Planet Nine';
const _settle = Duration(seconds: 6);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log a co-op session and advance the campaign board', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(_settle);

    if (find.text('HOME').evaluate().isNotEmpty) {
      await _signOut(tester);
      await tester.pumpAndSettle(_settle);
    }
    await _signInOrRegister(tester);
    await tester.pumpAndSettle(_settle);
    expect(find.text('HOME'), findsOneWidget);

    // ─── Open add-play and pick The Crew ─────────────────────────────────────
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.text('Select a game…'));
    await tester.pumpAndSettle(_settle);

    await tester.enterText(_searchField('Search games…'), 'The Crew');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.text(_crew).first);
    await tester.pumpAndSettle(_settle);

    // ─── Co-op controls replaced the winner UI ───────────────────────────────
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);

    // ─── Result = WON (visible now, before the form grows) ───────────────────
    await tester.tap(find.text('WON'));
    await tester.pumpAndSettle();

    // ─── Add a guest to satisfy minPlayers = 2 ───────────────────────────────
    await _scrollTap(tester, find.text('+ Add Participant'));
    await tester.enterText(
      _searchField('Search friends or add guest…'),
      'Ally',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Add guest'),
      ),
    );
    await tester.pumpAndSettle();
    (tester.state(find.byType(Navigator).first) as NavigatorState).pop();
    await tester.pumpAndSettle();

    // ─── Create a new table ──────────────────────────────────────────────────
    await _scrollTap(tester, find.text('Select a table'));
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.text('NEW TABLE'));
    await tester.pumpAndSettle(_settle);

    // Stage stepper defaults to mission 1.
    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('Mission 1 / 50'), findsOneWidget);

    // ─── Save ────────────────────────────────────────────────────────────────
    await tester.tap(find.text('Save Play'));
    await tester.pumpAndSettle(_settle);
    expect(find.text('HOME'), findsOneWidget);

    // ─── Open The Crew via catalog browse and verify the board advanced ──────
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.byTooltip('Browse all games'));
    await tester.pumpAndSettle(_settle);
    await tester.enterText(_searchField('Search games…'), 'The Crew');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.text(_crew).first);
    await tester.pumpAndSettle(_settle);

    // Campaigns section renders a table whose current mission advanced to 2
    // (mission 1 completed by the win), and the session shows a co-op result.
    expect(find.text('Campaigns'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text(' / 50'), findsWidgets);
    expect(find.textContaining('Team won'), findsWidgets);
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Finder _searchField(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Scrolls [finder] into view (it may sit below the fold) then taps it.
Future<void> _scrollTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  if (find
      .widgetWithText(ElevatedButton, 'Create Account')
      .evaluate()
      .isNotEmpty) {
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextFormField).at(0), _email);
  await tester.enterText(find.byType(TextFormField).at(1), _password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

Future<void> _signInOrRegister(WidgetTester tester) async {
  // Fresh emulator: register. Re-run with data present: fall back to sign-in.
  if (find.text('Register').evaluate().isNotEmpty) {
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextFormField).at(0), _email);
  await tester.enterText(find.byType(TextFormField).at(1), _password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
  await tester.pumpAndSettle(const Duration(seconds: 8));

  if (find
      .text('An account with this email already exists.')
      .evaluate()
      .isNotEmpty) {
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await _signIn(tester);
    return;
  }

  if (find.text('What should we call you?').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextFormField).first, _displayName);
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
