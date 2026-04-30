# Board Game Dashboard — Flutter App

## App Name

**Gameshelf** — the display name shown below the app icon on iOS and Android.

## Project Overview

A Flutter "super app" dashboard for tracking board game history and scores. Users can log games they've played, track win counts per player, and access game-specific utility tools (e.g., score calculators).

## Core Features

### 1. Game Library
- Display a list of board games the user has played
- Each game has a detail view showing play history and stats

### 2. Score Tracking
- Record play sessions: date, players, and outcome
- Track how many times each player has won per game
- Leaderboard view per game showing win counts

### 3. Game-Specific Tools
- Some games have dedicated utility screens (e.g., in-game score calculators)
- Tools are accessible from the game's detail page
- Each tool is self-contained and scoped to its game

## Tech Stack

- **Framework**: Flutter (Dart)
- **Target platforms**: iOS and Android (primary); desktop/web optional
- **State management**: TBD (prefer Riverpod or Bloc)
- **Local persistence**: TBD (prefer Isar or SQLite via `drift`)
- **Navigation**: `go_router`

## Project Structure (planned)

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

## Data Models (rough)

- **Game**: id, name, coverImageUrl, description, hasTools
- **Player**: id, name, avatarColor
- **Session**: id, gameId, date, playerResults (list of {playerId, score, isWinner})

## Game-Specific Tools (examples)

| Game | Tool |
|------|------|
| Wingspan | Score calculator (birds, eggs, food, bonuses) |
| Catan | Resource tracker / point calculator |
| Ticket to Ride | Score calculator (routes, longest road, tickets) |
| *(more to be added)* | |

## UI Task Verification (Required)

Before reporting any UI-related task as complete:

1. Run `flutter analyze` — fix all errors and warnings before declaring done
2. Run `flutter test` if widget tests exist for the changed screens
3. Run the app (`flutter run`) and visually verify the change looks correct on a simulator — do not skip this step
4. If a simulator is not available, explicitly say so rather than claiming the UI fix is done

A task is **not complete** until the UI has been visually confirmed. The `flutter analyze` hook will inject issues automatically, but static analysis cannot catch layout problems, overflow, wrong colors, or missing widgets.

## Coding Conventions

- Use `const` constructors wherever possible
- Prefer named routes via `go_router`
- Keep business logic out of widgets; use providers/blocs
- One file per widget/screen for files over ~150 lines
- No hardcoded strings in UI — use a constants file or l10n

## Out of Scope (for now)

- Cloud sync / multi-device support
- Online multiplayer
- BGG (BoardGameGeek) API integration
