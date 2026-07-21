# Handover — 2026-07-22

## Current Milestone

Implementing the **tester's feature-gap backlog** (`~/.claude/plans/i-want-you-to-flickering-nygaard.md`).
First-sprint items **H1, H2, H3, H5 are DONE** this session. Remaining next-up: Q2→Q1 (make repos
injectable + widget tests), then P1 (strings).

### Completed this session
- **H2 — edit play now persists location & notes.** Added `location`/`notes` to
  `UpdatePlayInput` (`lib/shared/models/play.dart`), the edit form
  (`lib/features/plays/edit_play_page.dart` — new `_StyledField`s + controllers), the backend
  (`functions/src/plays/updatePlay.ts` — writes them, `FieldValue.delete()` when cleared), and
  `play_detail_controller.dart` (optimistic state now reflects edited values). Backend jest tests
  added (set + clear).
- **H1 — score entry.** Added `_ScoreField` (numeric TextField, per the `[[feedback_score_input]]`
  preference — tappable field, not a stepper) to both the add and edit player rows.
  `ParticipantData` gained `score` + `updateParticipantScore`; the add screen keeps a parallel
  `_scoreControllers` list; the edit `_PlayerEntry` parses its own controller. `rank` left
  server-side for now.
- **H3 — no more silent save failures.** Add-play `_save` now awaits the CF and shows a SnackBar
  on failure instead of fire-and-forget + immediate pop. `main.dart` surfaces auth-stream errors
  via `_AuthErrorScreen` instead of silently showing the splash. (The edit path already had a
  SnackBar.)
- **H5 — play history + pagination.** New `PlayHistoryPage`
  (`lib/features/plays/play_history_page.dart`) with infinite scroll, backed by a new
  `PlayRepository.listMyPlays({limit, cursor})` calling the existing `listMyPlays` CF. Home's
  "Recent Plays" header (`home_tab.dart`) now shows the true lifetime count (library `playCount`
  sum = `totalGamesPlayed`, replacing the misleading capped list length) and a chevron that opens
  the history screen.

### Verification done
- `flutter analyze` clean; `flutter test` 66 pass (incl. new `add_play_notifier` score tests and
  a new `add_play_screen_test.dart` that renders the score + location/notes fields); `functions`
  jest updatePlay suite 16 pass against the Firestore emulator.
- App **builds and boots on the iOS iPhone 17 simulator**; the H5 Home header change ("N PLAYS" +
  chevron) is **visually confirmed** by screenshot. Could NOT interactively tap through to the
  Add/Edit/History screen *bodies* — no `idb`/`simctl tap` and macOS blocked AppleScript UI
  control. The add-screen widget test substitutes for Add; `PlayHistoryPage`'s runtime path is
  covered only by build + the already-tested `listMyPlays` CF, so its list rendering is **not yet
  interactively verified** (unblocked once repos are injectable — Q2).

## Context & Decisions

- The app is substantially further along than the previous handover implied: session logging
  (`features/plays/`), 5 score calculators, friends, and The Crew campaign sheet all exist now.
- Audit scope was set by the requester: emphasize **user-facing gaps, quality/testing gaps, and
  infra/polish**. Explicitly **out of scope**: writing new per-game score calculators for the
  ~109 tool-less catalog games. (The *generic campaign system* refactor is kept, as an
  architecture fix rather than a new calculator.)
- There are **zero TODO/FIXME markers** in `lib/` or `functions/src/`; every gap in the backlog
  was inferred by reading code.

## The 'Gravel' (non-obvious findings)

- **H1/H2/H3 DONE this session** (see Completed above). `rank` is still never set by the client —
  scores are entered but ranks are not derived; revisit if ranking matters.
- `ListMyPlaysResult.nextCursor` + the `listMyPlays` CF exist and are tested, but the client never
  paginates (hard limit ~10, no history screen). (H5)
- Campaign sheet is **hard-coded** to `the-crew-the-quest-for-planet-nine-2019`; the second seeded
  Crew game has none. (M4)
- Repositories are hand-rolled singletons (not Riverpod-provided) → core UI is largely untestable
  without a small refactor. (Q2)
- `getMyFriends` Cloud Function is dead (superseded by the `watchMyFriends` stream) — don't delete
  unasked, just flagged.
- `CLAUDE.md` documents `lib/features/games/` and `lib/features/sessions/`, but neither exists /
  both are empty; real code is in `library/` and `plays/`.

## Next Immediate Step

**Q2 — make repositories injectable** (then Q1 — widget tests). Wrap `PlayRepository`,
`FriendRepository`, `CampaignRepository`, `GameCatalogRepository` in Riverpod `Provider`s (keep the
singleton internally, or inject `FirebaseFirestore`/`FirebaseFunctions`) so widget tests can
override them with fakes. This also unblocks interactive/widget verification of `PlayHistoryPage`
and the Add/Edit play screens left pending above.
