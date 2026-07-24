# Gameshelf — Tester's Feature-Gap Report & Implementation Backlog

## Context

This is a QA/tester audit of the **Gameshelf** Flutter app (board-game play tracker on
Firebase). The goal is a prioritized, actionable backlog of (a) **incomplete/broken
user-facing features**, (b) **quality & testing gaps**, and (c) **infra & polish** — detailed
enough to implement later. Per the requester's direction, this report **de-emphasizes new
per-game calculators** (only a structural note is kept) and does **not** propose speculative
"nice to have" features that aren't grounded in the current code.

The app is more built-out than `HANDOVER.md` (2026-04-30) suggests: session logging, 5 score
calculators, friends, and The Crew campaign sheet all now exist. There are **zero `TODO`/`FIXME`
markers** in `lib/` or `functions/src/` — so all incompleteness below was inferred by reading the
code, not from annotations. Effort key: **S** ≈ <½ day, **M** ≈ ½–2 days, **L** ≈ >2 days.

Current shell has only **2 tabs** (Home, Library) + an Add-Play FAB; Friends/Profile are reached
only via the app-bar avatar. Writes go through Cloud Functions; the client reads Firestore directly.

---

## HIGH PRIORITY — broken or unreachable existing functionality

These are features the code *already half-supports* (models, backend, or detail views exist) but
that the user cannot actually reach or complete. Highest value because the plumbing is mostly done.

### H1. Score entry is unreachable in Add/Edit Play — **M**
- **What's wrong:** `ParticipantInput`/`ParticipantResult` carry a `score` field, `createPlay`
  accepts it, and `play_detail_page.dart` *renders* scores and ranks — but neither
  `lib/features/plays/add_play_screen.dart` nor `edit_play_page.dart` lets a user type a score.
  Scores can therefore only ever be null. `rank` is never set by the client at all.
- **Fix:** add a score `TextField` per participant row in `add_play_notifier.dart` /
  `participant_list_section.dart` (respect the memory `[[feedback_score_input]]`: tappable
  TextField + numeric keyboard, not steppers). Derive `rank` from sorted scores (or let it stay
  server-computed). The score calculators (Wingspan, 7 Wonders, etc.) are a natural feeder — a
  later enhancement could "send total to a play," but v1 is just manual entry.
- **Files:** `lib/features/plays/add_play_notifier.dart`, `add_play_screen.dart`,
  `edit_play_page.dart`, `participant_list_section.dart`; model `shared/models/play.dart`.

### H2. Editing a play silently drops location & notes — **S**
- **What's wrong:** `UpdatePlayInput` has **no** `location`/`notes` fields, so editing a play cannot
  change them, and `play_detail_controller.dart` keeps stale values after an edit
  (`state.location ?? …`). `functions/src/plays/updatePlay.ts` likely needs to accept them too.
- **Fix:** add `location`/`notes` to `UpdatePlayInput.toJson()`, the edit form, and `updatePlay.ts`;
  verify the detail controller re-reads them. Add a jest case to `functions/test/updatePlay.test.ts`.

### H3. Play creation/edit failures are silent — **S/M**
- **What's wrong:** saves are fire-and-forget (`.ignore()`), so a failed `createPlay`/`updatePlay`
  shows no error; the user thinks it worked. `main.dart`'s auth gate also swallows `snapshot.hasError`
  into the splash screen.
- **Fix:** await the CF call, show a SnackBar on failure, keep the form open on error. Surface auth
  errors in `_buildHome` instead of falling back to splash.

### H4. Friend profile shows no play history / no head-to-head — **M**
- **What's wrong:** `friend_profile_screen.dart` shows only aggregates (win %, games, top-5) and is a
  one-shot `Future` cached in `initState` (no live refresh). There's no way to see a friend's actual
  plays or your shared/head-to-head record — arguably the whole point of adding friends.
- **Fix:** add a "shared plays" list (query `plays` where `participantIds array-contains` both uids —
  note Firestore allows only one `array-contains`, so query on self + client-filter for the friend,
  or add a backend read). Consider a small head-to-head W/L tile.
- **Files:** `friend_repository.dart`, `friend_profile_screen.dart`; possibly a new CF read.

### H5. Recent-plays list has no pagination / no full history — **M**
- **What's wrong:** `ListMyPlaysResult { plays, nextCursor }` and the `listMyPlays` CF (cursor,
  max 100) exist and are tested, but the client only ever calls `watchRecentPlays` with a hard
  limit (~10). There is **no "all plays" / history screen** and `nextCursor` is dead code on the
  client. Home's "sessions" count reflects only the fetched 10, not the true total.
- **Fix:** add a paginated "Play History" screen backed by `listMyPlays` + infinite scroll; link it
  from Home's section header. Use the real `stats/{uid}.totalGamesPlayed` for the count.

### H6. No password reset & no avatar for email/password users — **S each**
- **What's wrong:** `login_screen.dart` has no forgot-password flow (`sendPasswordResetEmail` unused).
  `photoUrl` only ever comes from Google, so email/password users are stuck with initials forever.
- **Fix:** add a "Forgot password?" link on login. (Photo upload needs `image_picker` +
  Firebase Storage — see P4; treat avatar upload as Medium/infra-dependent.)

---

## MEDIUM PRIORITY — visible gaps that need net-new (but small) surfaces

### M1. No way to browse the full game catalog — **M**
- **What's wrong:** the 115-game `boardGames` catalog is only reachable through the game-picker
  *while logging a play*. "Library" = only games you've already logged. There's no browse/explore
  screen, so tools & campaign sheets for un-played games are effectively hidden.
- **Fix:** add a catalog browse screen (reuse `game_catalog_provider.dart` search + `game_picker_sheet`
  patterns) that opens `GameDetailPage` for any game, not just owned ones. Could be a 3rd tab or a
  header action on Library.

### M2. Shell navigation is thin — Friends/Profile/Tools buried — **M**
- **What's wrong:** `main_shell.dart` is a 2-item `IndexedStack` (Home, Library). Friends and Profile
  hang off the avatar; there's no Friends tab, no stats/leaderboard destination.
- **Fix:** promote Friends (or a combined "Social") into the bottom nav; consider a stats/leaderboard
  destination once M3 exists. Keep imperative `Navigator` (no need for go_router yet).

### M3. Home dashboard has no trends/streaks/leaderboard — **M**
- **What's wrong:** Home shows exactly three client-computed numbers (plays, wins, win%) folded from
  the library stream. `CLAUDE.md` and `HANDOVER.md` both mention a per-game/per-player leaderboard
  that was never built. `stats/{uid}` + `gameStats` already hold the data server-side.
- **Fix (no new deps):** add a per-game win-count leaderboard and a "most-played" list from
  `gameStats`. Charting is optional and gated on P5 (no chart lib today) — start with simple bars
  like the existing `library_tab` win-rate bar.

### M4. Generic campaign system (currently hard-coded to one game) — **M**
- **What's wrong:** the campaign record sheet is hard-coded to `the-crew-the-quest-for-planet-nine-2019`
  (`crew_record_section.dart`, `kTheCrewMissionCount = 50`) and gated by an `if (gameId == …)` in
  `game_detail_page.dart`. The second seeded Crew game (`the-crew-mission-deep-sea-2021`) has no sheet.
  Data model `CrewCampaign` is Crew-specific.
- **Fix:** generalize into a registry-driven campaign system mirroring the tools registry
  (`kCampaignRegistry[gameId] -> CampaignSpec`), so campaign sheets scale the way tools do. This is
  the one "new tool" item kept, because it's a structural/architecture fix, not a new calculator.
- **Note:** per requester direction, adding *new per-game score calculators* for the ~109 tool-less
  games (Catan, Azul, Splendor, Ticket to Ride, …) is **out of scope** for this backlog.

---

## QUALITY & TESTING GAPS

Backend/jest coverage is strong (createPlay 20, updatePlay 14, deletePlay 14, reads 22, friends ~30).
Flutter-side coverage is sparse and tool-heavy. The repositories are hand-rolled singletons
(`static final instance`) rather than Riverpod-provided, which is the main thing blocking mockable
widget tests.

### Q1. No widget tests for any core screen — **M (spread over several)**
- **Untested UI:** all auth screens, all friends screens, `home_tab`, `library_tab`,
  `game_detail_page`, `main_shell`, `add_play_screen`, `edit_play_page`, `play_detail_page`,
  participant picker/search, `game_picker_sheet`, `profile_app_bar`. `test/widget_test.dart` only
  renders the 7 Wonders Duel calculator.
- **Fix:** prioritize `add_play_notifier` already has a test — extend to the full add-play widget;
  add golden/interaction tests for `home_tab` states (loading/empty/error) and `library_tab`.

### Q2. Repositories/providers untestable without refactor — **M**
- **What's wrong:** `play_repository`, `friend_repository`, `campaign_repository`,
  `game_catalog_repository` are singletons, not injected. No tests exist for any repo or provider.
- **Fix:** wrap each repo in a Riverpod `Provider` (keep the singleton internally for now, or inject
  `FirebaseFirestore`/`FirebaseFunctions`) so widget tests can override with fakes.

### Q3. Two calculators & two backend functions untested — **S**
- **What's wrong:** `lost_cities` and `terraforming_mars` calculators have no tests (the other three
  do). `listBoardGames` and the `syncUserSearchOnCreate/OnUpdate` triggers have no jest tests.
- **Fix:** mirror the existing `wingspan_calculator_test.dart` pattern for the two calculators; add
  jest tests for `listBoardGames` (prefix search, limits) and the userSearch triggers.

### Q4. Integration test uses hard-coded prod credentials — **S**
- **What's wrong:** `integration_test/app_test.dart` (TC-01…TC-09) runs against **real Firebase** with
  hard-coded test credentials — brittle and unsafe to run in CI.
- **Fix:** point it at the emulator suite (`_useEmulators` path already exists in `main.dart`) and
  read creds from `--dart-define`.

---

## INFRA & POLISH

### P1. `CLAUDE.md` "no hardcoded strings" rule is violated everywhere — **M**
- **What's wrong:** there is **no** l10n (`flutter_localizations`/`intl`/`.arb`/`l10n.yaml`) and **no**
  shared constants/strings file. Every UI string is inline, directly contradicting the project rule.
- **Fix:** either set up `flutter_localizations` + an `app_en.arb`, or (lighter) a
  `lib/shared/strings.dart` constants file. Decide with the requester which the rule intends.

### P2. Single fixed dark theme; no light mode / no theme switch — **M**
- **What's wrong:** `app_theme.dart` is one `const` dark palette; no `ThemeMode`, no light theme, no
  persistence. `MaterialApp` has no `darkTheme`/`themeMode`.
- **Fix:** add a light theme + a `themeMode` setting persisted (needs `shared_preferences` — see P4),
  exposed on the Profile/Settings screen.

### P3. No analytics, crash reporting, or perf monitoring — **S each**
- **What's absent:** no `firebase_analytics`, no Crashlytics/Sentry, no `firebase_performance`.
  Logging is ad-hoc `dev.log`/`console.log`.
- **Fix:** add Crashlytics first (highest value for a shipping app), then analytics for key funnels
  (login, add-play, add-friend).

### P4. Missing capability packages block several items above — **S (setup) + dependent work**
- **What's absent:** no `image_picker`/Firebase Storage (blocks H6 avatar upload), no
  `shared_preferences` (blocks P2 theme persistence, any local settings), no charts (limits M3), no
  notifications (FCM/local — there's no way to notify a user of an incoming friend request).
- **Fix:** add packages as the dependent features are scheduled; don't add speculatively.

### P5. No settings screen — **S**
- **What's wrong:** Profile is name + email + Friends link + Sign Out. There's no home for
  theme, notifications, about/version, or account deletion.
- **Fix:** a lightweight Settings screen consolidating P2/P3 toggles and an "About" section.

### P6. Housekeeping — **S**
- Committed emulator logs (`firestore-debug.log` in repo root and `functions/`) should be
  git-ignored/removed. Empty documented dirs `lib/features/games/` and `lib/features/sessions/` either
  should be created-with-content or removed from `CLAUDE.md` to match reality (they don't exist / are
  empty; actual code lives in `library/` and `plays/`). The `getMyFriends` Cloud Function is dead
  (superseded by the `watchMyFriends` stream) — flag for the owner, don't delete unasked.

---

## Suggested first sprint (if you want a starting order)

1. **H2** (edit drops notes/location) + **H3** (silent failures) — small, high-trust wins.
2. **H1** (score entry) — the single biggest "why can't I do this?" gap.
3. **H5** (play history + pagination) — unlocks dead backend code.
4. **Q2 → Q1** (make repos injectable, then start widget tests) — pays for all later UI work.
5. **P1** (strings) — stop the rule violation from growing.

---

## Verification (how to validate any item once built)

- `flutter analyze` must be clean (the analyze hook enforces this) and `flutter test` green.
- For plays/friends changes, run against the **emulator suite** (`firebase emulators:start`, set
  `_useEmulators = true` in `main.dart` — remember Auth+Functions must BOTH be on) and exercise the
  flow end-to-end, then flip back to `false`.
- Per `CLAUDE.md` UI rule: run the app on a simulator and **visually confirm** each UI change
  (score field, edit form, history list) — static analysis won't catch layout/overflow.
- For backend items (H2/Q3): add/extend jest tests under `functions/test/` and run
  `npm test` in `functions/`.
- Check `firestore.rules` for any new read/write path (e.g. shared-plays query in H4) before wiring
  client code; deploy rules in the same task if changed.

## Explicitly out of scope (per requester)
- New per-game **score calculators** for the ~109 tool-less catalog games. (The *generic campaign
  system* M4 is kept because it's an architecture fix, not a new calculator.)
