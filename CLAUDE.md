# Board Game Dashboard — Flutter App

## App Name

**Gameshelf** — the display name shown below the app icon on iOS and Android.

## Project Overview

A Flutter "super app" dashboard for tracking board game history and scores. Users can log games they've played, track win counts per player, and access game-specific utility tools (e.g., score calculators).

## Tech Stack

- **Framework**: Flutter (Dart)
- **Target platforms**: iOS and Android (primary); desktop/web optional
- **State management**: Riverpod
- **Local persistence**: Firebase Firestore
- **Navigation**: `Navigator.of(context).push` (imperative)

## Project Structure

```
lib/
  main.dart
  features/
    auth/                   # Login & profile setup
    friends/                # Friend management & profiles
    home/                   # Home dashboard
    library/                # Game library, game detail & catalog browse
    plays/                  # Play logging, history & detail
    shell/                  # Main navigation shell
    tools/                  # Game-specific utility tools
      <game_name>/          # One subfolder per game with tools
      registry/             # game_tools_registry.dart — new tools MUST be registered here
  shared/
    models/                 # Data models (Game, Session, Player, etc.)
    providers/              # Riverpod providers
    repositories/           # Firestore data access
    widgets/                # Reusable UI components
    theme/                  # App theme & colors
functions/                  # Cloud Functions (TypeScript) — own package.json, jest tests
```

## Commands

- `flutter run` / `flutter test` / `flutter analyze` — app dev loop
- `flutter test integration_test` — integration tests
- `firebase emulators:start` — Firestore :8080, Functions :5001, Auth :9099, UI :4000
- In `functions/`: `npm run build`, `npm test`, `npm run deploy`
- `node functions/seed-board-games.js` — seed game data (also `clear-firestore.js`, `backfill-user-search.js`)

## UI Task Verification (Required)

Before reporting any UI-related task as complete:

1. Run `flutter analyze` — fix all errors and warnings before declaring done
2. Run `flutter test` if widget tests exist for the changed screens
3. Run the app (`flutter run`) and visually verify the change looks correct on a simulator — do not skip this step
4. If a simulator is not available, explicitly say so rather than claiming the UI fix is done

A task is **not complete** until the UI has been visually confirmed. The `flutter analyze` hook will inject issues automatically, but static analysis cannot catch layout problems, overflow, wrong colors, or missing widgets.

## Coding Conventions

- Use `const` constructors wherever possible
- Keep business logic out of widgets; use providers/blocs
- One file per widget/screen for files over ~150 lines
- No hardcoded strings in UI — use a constants file or l10n

## Firestore Rules

Always check `firestore.rules` when implementing any feature that reads from or writes to Firestore. Verify that the security rules permit the intended operations for the authenticated user before writing client-side code. If a required permission is missing, update `firestore.rules` and deploy with `firebase deploy --only firestore:rules` as part of the same task.

## Gotchas

- `lib/main.dart` reads `_useEmulators` from `--dart-define=USE_EMULATORS=true` (defaults to
  false → production). Pass that define ONLY while `firebase emulators:start` is running; the
  integration test suite passes it automatically. Auth and Functions emulators must BOTH be on
  or BOTH off — mixing emulator auth tokens with production Functions causes INTERNAL errors.
- Session hand-offs go in `HANDOVER.md` at the repo root.

