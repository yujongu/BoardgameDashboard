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
  app.dart                  # Root widget, router setup
  features/
    games/                  # Game library & detail views
    sessions/               # Play session logging & history
    players/                # Player management
    tools/                  # Game-specific utility tools
      <game_name>/          # One subfolder per game with tools
  shared/
    models/                 # Data models (Game, Session, Player, etc.)
    widgets/                # Reusable UI components
    theme/                  # App theme & colors
```

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

## Think Before Coding

Before implementing, state assumptions explicitly — if uncertain, ask. If multiple interpretations exist, present them rather than picking silently. If a simpler approach exists, say so and push back when warranted. If something is unclear, stop and name what's confusing before proceeding.

## Simplicity First

Write the minimum code that solves the problem. No features beyond what was asked, no abstractions for single-use code, no unrequested flexibility or configurability, no error handling for impossible scenarios. If 200 lines could be 50, rewrite it. Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical Changes

Touch only what is necessary. When editing existing code: don't improve adjacent code, comments, or formatting; don't refactor things that aren't broken; match existing style even if you'd do it differently. If you notice unrelated dead code, mention it — don't delete it. Remove imports/variables/functions that your changes made unused, but don't remove pre-existing dead code unless asked. Every changed line should trace directly to the request.

## Goal-Driven Execution

Transform tasks into verifiable goals before starting:
- "Add validation" → write tests for invalid inputs, then make them pass
- "Fix the bug" → write a test that reproduces it, then make it pass
- "Refactor X" → ensure tests pass before and after

For multi-step tasks, state a brief plan with a verify step for each stage. Strong success criteria allow independent looping; weak criteria ("make it work") require constant clarification.

