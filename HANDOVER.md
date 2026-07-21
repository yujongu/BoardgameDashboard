# Handover — 2026-07-22

## Current Milestone

Implementing the **tester's feature-gap backlog** (`~/.claude/plans/i-want-you-to-flickering-nygaard.md`).
Items **H1, H2, H3, H5, Q2, Q1 are DONE** this session. Remaining next-up: P1 (strings/l10n),
then H4 (friend play history), M1 (catalog browse), etc.

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
- **Q2 — repositories are injectable.** New `lib/shared/providers/repository_providers.dart`
  exposes all four repos as Riverpod `Provider`s (returning the existing singletons). Every call
  site now reads the provider instead of `Repository.instance` (the only remaining `.instance` is
  the intentional default in `AddPlayNotifier`'s constructor). Notifiers take the repo via
  constructor; `game_detail_page` and `crew_record_section` were converted to `ConsumerStatefulWidget`.
- **Q1 — widget/unit tests unblocked by Q2.** New `play_history_page_test.dart` (renders first
  page + loads next page on scroll, via a fake repo override) and new `AddPlayNotifier.save()`
  tests (success + failure-surfaces-`saveError`, i.e. H3). This is the interactive-verification
  substitute that was pending for the history screen.

### Verification done
- `flutter analyze` clean; `flutter test` **70 pass**; `functions` jest updatePlay suite 16 pass
  against the Firestore emulator.
- App **builds and boots on the iOS iPhone 17 simulator** after the Q2 refactor (home renders from
  real Firebase through the provider-wired repos — confirms runtime wiring). H5 Home header ("N
  PLAYS" + chevron) **visually confirmed** by screenshot.
- Interactive tap-through to Add/Edit/History screen *bodies* is still blocked (no `idb`/`simctl
  tap`, macOS blocks AppleScript UI control), but the History list rendering + pagination is now
  covered by `play_history_page_test.dart` (fake-repo override), so it's no longer unverified.

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

**P1 — kill hardcoded strings** (the CLAUDE.md rule with nothing behind it). Decide with the owner:
`flutter_localizations` + `app_en.arb`, or a lighter `lib/shared/strings.dart` constants file. Then
migrate inline UI strings. After that, good candidates are H4 (friend shared-play history) and M1
(a catalog-browse screen) — both now easier to test thanks to the Q2 injectable repos.
