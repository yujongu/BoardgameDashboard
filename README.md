# Gameshelf

A Flutter app for tracking board game plays and scores. Log sessions, view play history, and use in-game score calculators — all in one place.

## Features

- **Play logging** — record completed game sessions with players, scores, and outcomes
- **Game library** — browse your tracked games and view per-game play history
- **Friends** — connect with other users to track shared play history
- **Score calculators** — in-game tools for games like Lost Cities (more planned)
- **Google Sign-In** — authentication backed by Firebase

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| State management | Riverpod |
| Backend / database | Firebase Firestore |
| Auth | Firebase Auth + Google Sign-In |
| Navigation | Imperative (`Navigator.push`) |

## Project Structure

```
lib/
  main.dart
  app.dart
  features/
    auth/         # Login, profile setup, profile screen
    home/         # Home tab (dashboard)
    library/      # Game library and detail pages
    plays/        # Log and view play sessions
    friends/      # Friends list and requests
    tools/        # In-game score calculators
      lost_cities/
  shared/
    models/       # Play, Friend, CatalogGame, …
    providers/    # Riverpod providers
    repositories/ # Firestore data access
    widgets/      # Shared UI components
    theme/        # App theme and colors
```

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.5`
- A Firebase project with Firestore, Authentication (Google provider), and Cloud Functions enabled
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) placed in the standard locations

### Run

```bash
flutter pub get
flutter run
```

### Analyze

```bash
flutter analyze
flutter test
```
