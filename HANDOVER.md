# Handover — 2026-07-28 (session: The Crew mission "tries" logging)

## Current Milestone

**Rework the co-op *campaign* log-a-play flow (The Crew) to surface per-mission
tries and log one attempt at a time against the current mission.** Plan file:
`~/.claude/plans/for-the-crew-game-velvety-chipmunk.md` (approved).

Status: **implemented; `flutter analyze` clean; `flutter test` 291 pass; NOT
committed.** No iOS/Android simulator on this Windows box (only Windows desktop +
Chrome/Edge web), and the new UI sits behind auth + table selection, so the
on-device pixel check was **not** performed. The new widgets are exercised by
widget tests that render them with the production theme and assert their contents
(table-picker-only state, mission record list, PASSED/FAILED, the non-campaign
RESULT path).

## Context & Decisions (this session)

- **User's confirmed model** (via AskUserQuestion): a "try" = one logged attempt
  (win/loss); **one mission per log**; this **replaces** the old Won/Lost + free
  stage-picker arrangement for campaign games; past missions are **editable**.
- **Key reuse, not rebuild**: the backend already implements the progression —
  `functions/src/plays/createPlay.ts` increments `sessionCount` per attempt and
  latches `completed` on a win. So `sessionCount` **is** the tries count; **no
  cloud-function or `firestore.rules` change was needed.** Added
  `Campaign.triesFor(stage)` (`lib/shared/models/campaign.dart`) as a read accessor.
- **Log-a-play UI** (`lib/features/plays/add_play_screen.dart`): `_CoopControls`
  now branches. One-shot co-ops (Pandemic) keep the RESULT WON/LOST row (factored
  into a small `_OutcomeRow`). Campaign games show: TABLE picker → `_MissionRecordList`
  (current mission first, then completed history, each row tappable to edit) →
  `_CurrentMissionAttempt` (pinned current mission + PASSED/FAILED). The free
  `_StageStepper` was **deleted**. Stage is auto-pinned via the existing
  `AddPlayNotifier.setCampaign` → `nextIncompleteStage`.
- **Editing** (`_editMission` + `_EditMissionDialog`) rebuilds the `stages` map and
  persists via the existing `campaignRepository.saveCampaign` (which already carries
  `sessionCount` through `CampaignStage.toJson`), then re-pins the current mission by
  calling `setCampaign` on the updated campaign.
- **l10n**: added `crewMissionRecordCaps`, `crewTriesCount` (ICU plural),
  `crewPassed`, `crewFailed`, `crewEditMissionTitle`, `crewTriesLabel`,
  `crewMissionPassed` to `lib/l10n/app_en.arb`; regenerated with `flutter gen-l10n`.
- **Scope trim**: the plan's optional §5 (mirror the tries list on the Game Detail
  `CampaignCard`) was **reverted** — up to ~96 rows on the always-visible card
  overflowed and broke `campaign_card_test.dart`, and it wasn't part of the request.
  The card is unchanged from `main`.
- **Docs**: `docs/manual-test-plan.md` Part 4 rewritten for the new flow, and repro
  1.12 annotated (the free stepper is gone from Add Play; it only remains on the
  Game Detail board card).

## The 'Gravel' (non-obvious)

- `flutter/material.dart` does **not** re-export `FilteringTextInputFormatter`; the
  explicit `import 'package:flutter/services.dart';` in `add_play_screen.dart` is
  required. The analyzer's transient "unnecessary import" warning was a false
  positive from an intermediate state before the dialog code existed.
- `Switch.activeColor` is deprecated in this SDK → use `activeThumbColor`.
- `_MissionRecordList` renders `for (n = current; n >= 1; n--)` — fine inside Add
  Play's `SingleChildScrollView`, but do **not** drop it into a height-bounded parent
  (that's exactly what broke the Game Detail card).
- `AppStrings.addPlayStageCaps` ("STAGE") and `AddPlayNotifier.setStage` are now
  unused by the UI; both left in place (pre-existing string / harmless public API).

## Next Immediate Step

On-device visual pass: `firebase emulators:start` then
`flutter run --dart-define=USE_EMULATORS=true`, log The Crew → pick a table → verify
the MISSION RECORD list, pinned CURRENT MISSION, PASSED/FAILED, and the edit-mission
dialog render/behave in light + dark. Then branch off `main` and commit — first file
to touch is `lib/features/plays/add_play_screen.dart`.

---

# Handover — 2026-07-28 (session: 28 score calculators)

## Current Milestone

**Score-calculator tools for 28 more catalog games (5 → 33 total).** Plan file:
`~/.claude/plans/i-want-you-to-piped-turing.md`. Approved scope: all 28 "strong-fit"
games (those whose final score is an additive tally); **bespoke screen per game**; **full
l10n**. Co-op / social-deduction / party / abstract games were deliberately excluded.

Status: **fully implemented; `flutter analyze` clean; `flutter test` 289 pass; NOT
committed.** Each new tool has unit tests for the pure scoring/winner fns + 2 widget
tests. **No iOS/Android simulator on this Windows box** (only Windows desktop + Chrome/
Edge web) — the pixel-level on-device check was **not** performed. The 28 widget tests do
render every screen with the production theme, and a `RenderFlex` overflow throws during
`pumpWidget`, so the passing build-smoke tests confirm no overflow at the default surface.

## Context & Decisions (this session)

- **Template**: every tool is a structural copy of `lib/features/tools/wingspan/` — a
  top-level pure `<game>Total({...})` + `<game>Winners(List<int>)`, a category `enum` +
  `label(AppStrings)` resolver extension, and a `StatefulWidget` composing the **unchanged**
  shared `SelectorChipRow` / `ScoreInputRow` / `CalculatorTotalsBar`
  (`presentation/widgets/calculator_widgets.dart`).
- **Scoring model**: each category is a **VP subtotal the player enters** (adding aid, not
  a rules engine). Fixed multipliers live in the total fn (e.g. Azul columns ×7); penalties
  subtract; negatives use `ScoreInputRow(signed: true)` (Sushi Go puddings, Sushi Go Party
  desserts, Point Salad cards).
- **Special scoring**: Tigris & Euphrates total = `min(4 colours)` with a section header
  showing the score; Photosynthesis total = tokens only, remaining light is a **winner
  tiebreak** (mirrors 7 Wonders coins → `photosynthesisWinners({totals, light})`); Blokus =
  `allPlaced*15 + monomino*5 − remaining` (can be negative); Takenoko emperor ×2; Kingdomino
  Middle Kingdom +10 / Harmony +5; Patchwork `buttons + 7×7*7 − empty*2` (**2-player-only**,
  no player selector).
- **Point Salad**: scoring cards are randomised per game, so the tool is a 6-row **signed**
  per-player adder (documented in-file), not a category breakdown.
- **l10n**: full ARB (`generate: true` + `l10n.yaml`). ~200 keys added to
  `lib/l10n/app_en.arb`, regenerated via `flutter gen-l10n`. Per-game prefixes (`azul*`,
  `csc*`, `ttr*`, `conc*`, …). Two parametrized keys: `ptsCard(n)`, `tigrisScoreHeader(score)`.
  Generated `app_localizations*.dart` is **git-ignored** (regenerate on pub get / gen-l10n).
- **Registry** `lib/features/tools/registry/game_tools_registry.dart` now has **33 game-id
  keys**. No Firestore rules change — tools read/write nothing.

## The 'Gravel' (non-obvious)

- **Widget-test finder trap**: `find.widgetWithText(TextField, '')` **drops** a field once
  it has text, shifting later `.at(n)` indices → use `find.byType(TextField).at(n)` (stable).
  And when the total equals an entered field value (Tigris `min`, Photosynthesis `tokens`),
  `find.text(total)` matches **both** the input and the totals bar → assert the unique player
  chip `find.text('P1 · N')` instead.
- **Wave-1 undercount**: the tile/pattern group is **7** games; the first pass built 5 and
  **missed Kingdomino & Patchwork** (added afterward as "Wave 1b"). All 28 are present now —
  re-derive the count from the plan's list, not a task title.
- **Nothing committed** — all working-tree on `main`. Branch before committing. Commit set =
  new `lib/features/tools/<game>/` screens + `lib/l10n/app_en.arb` + the registry + the new
  `test/features/tools/<game>/` tests (generated l10n is git-ignored, so don't commit it).
- Heavier euros (Concordia, Castles of Burgundy, Scythe, etc.) are additive subtotals — the
  calculator sums what's typed, it can't validate a category. That's the intended "simple"
  ceiling for this task.

## Next Immediate Step

Visual pass on a device/emulator (none on this box): open the game-detail page for a sample
across the three groups — **Azul, Ticket to Ride, Concordia, Tigris & Euphrates, Patchwork** —
confirm the Score Calculator card appears and each screen renders without overflow / with
working player-switching + totals. Then branch + commit.

---

# Handover — 2026-07-24 (session 2: cooperative play logging)

## Current Milestone

**Cooperative / campaign game support (Option 4 — unification).** Games like The Crew,
Gloomhaven, and Pandemic have no winner: a team completes stages or wins/loses together. Logging a
co-op session now (a) records a play AND (b) advances a **shared, table-scoped campaign board**
atomically. Plan file: `~/.claude/plans/streamed-waddling-rain.md`. **v1 is phased to 3 games**:
The Crew ×2 (linear missions), Gloomhaven (scenario board), Pandemic (one-shot, no board).

Status: **fully implemented and verified end-to-end on the iOS simulator; NOT yet committed.**
`flutter analyze` clean; **93 Flutter tests** + **132 Functions tests** pass; a new
`integration_test/coop_test.dart` drives the full co-op flow on an iPhone sim against the
emulator suite (register → log a WON Crew mission on a new table → verify the campaign board
advanced to Mission 2 with a "Team won · Mission 1" history row) — **passing**.

### Two bugs the iOS run surfaced and fixed (both committed to the working tree)
1. **`functions/src/shared/db.ts` used the wrong emulator project.** It hardcoded
   `projectId: "demo-boardgame-test"` whenever `FIRESTORE_EMULATOR_HOST` was set. The
   Firestore emulator partitions data **per project id**, so the real app (`gameshelf-283dc`)
   wrote campaigns the Function could never read → co-op saves failed with "Campaign not
   found." Fixed to `process.env.GCLOUD_PROJECT || "demo-boardgame-test"` (jest pre-initializes,
   so it's unaffected; the Functions emulator injects the real project). This was a **latent
   pre-existing bug** affecting ALL app→Function emulator writes, not just co-op.
2. **`firebase.json` had no `auth` emulator entry**, so `--only auth` was silently ignored
   ("Not starting the auth emulator") and sign-in failed. Added `"auth":{"port":9099}`.

### How to re-run the iOS integration test
```
cd functions && npm run build
firebase emulators:start --only auth,functions,firestore --project gameshelf-283dc   # background
(cd functions && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=gameshelf-283dc \
   node seed-board-games.js board-games-seed.json)                                    # seed catalog
xcrun simctl boot <iphone-udid>
flutter test integration_test/coop_test.dart -d <iphone-udid> --dart-define=USE_EMULATORS=true
```

## Context & Decisions (this session)

- **Locked product decisions:** (1) co-op plays do **not** touch win stats — the `createPlay`
  co-op branch skips all `stats`/`gameStats`/`library` writes; (2) campaigns are **table-scoped**
  in a **new top-level `campaigns/{campaignId}`** collection (not `users/{uid}/campaigns/{gameId}`)
  — one shared doc per table, so "everyone at the table advances" needs no fan-out; (3) phased v1.
- **Registry** `lib/features/library/campaign_registry.dart`: `CampaignSpec{missionCount}` → generic
  `CoopSpec{hasCampaign, stageAxis(enum), stageCount}`. `coopSpecForGame` (any co-op game) +
  `campaignForGame` (only games with a board).
- **Model** `lib/shared/models/campaign.dart` (new, Firebase-free): `Campaign` + `CampaignStage`
  (stages keyed by id "1".."N"; `nextIncompleteStage` derives the linear "current"). Co-op fields
  added to `play.dart` (`PlayMode` enum, `outcome`, `campaignId`, `stageId`, `difficulty`,
  `teamScore`) on `CreatePlayInput`/`PlaySummary`/`PlayDetail`.
- **Cloud Function** `functions/src/plays/createPlay.ts`: `mode` discriminator. Co-op skips the
  winner check + all aggregate writes; if `campaignId` present, reads the campaign (verifies caller
  ∈ `memberIds`), and in the same transaction advances `stages[stageId]` (`completed` **latches**
  true on a win, `sessionCount++`). `listMyPlays` + `PlayDocument` type now return co-op fields.
- **Repository** `campaign_repository.dart` retargeted to `campaigns/{campaignId}`:
  `createCampaign`, `fetchCampaignsForGame` (array-contains uid + gameId), `saveCampaign`.
- **Rules/index:** new `campaigns` block (member read; creator-includes-self create; member
  update/delete — server advances bypass via Admin SDK) + composite index (memberIds + gameId).
- **UI:** `crew_record_section.dart`/`crew_campaign.dart` **deleted**, replaced by
  `campaign_record_section.dart` (`CampaignSection` lists a game's tables + "new table";
  `CampaignCard` = generalized Crew card). `game_detail_page.dart` shows it for any board game +
  renders co-op history rows ("Team won · Mission N"). `add_play_screen.dart`/notifier gain a co-op
  branch (WON/LOST + table picker + stage stepper, winner UI hidden). `play_detail_page.dart` shows
  a co-op result banner and **hides edit** for co-op plays.

## The 'Gravel'

- **On-device verification: DONE** on the iPhone 17 simulator via `integration_test/coop_test.dart`
  (see above). Note: co-op games do NOT appear in the **Library** tab (co-op skips library
  writes), so the campaign board is reached via **Library → Browse all games** (catalog browse).
  Worth confirming this is the intended discovery path — or reconsider excluding co-op from
  library `playCount` (see assumption below).
- **Nothing committed.** All changes are working-tree only, on `main`. Branch before committing.
  Includes the `db.ts` + `firebase.json` fixes above.
- **Rules/index not deployed** (`firebase deploy --only firestore:rules,firestore:indexes`).
- **Co-op edit is intentionally disabled** — `updatePlay` is still winner-centric; editing a co-op
  play would fail, so the edit button is hidden for them. Deferred.
- **Assumption baked in:** co-op plays are excluded from library `playCount` too (not just wins).
  They still appear in game-detail history via `fetchPlaysByGame`. Revisit if the user wants co-op
  plays counted in the "plays" totals.
- Legacy Crew data migration is a **script, not yet run**: `functions/migrate-crew-campaigns.js`
  (idempotent via a `migratedFrom` marker). Run once before/after deploy.
- Gloomhaven uses a **flat 95-scenario count** (no branching tree) for v1.

## Next Immediate Step

Start emulators (`firebase emulators:start`), run the app with
`flutter run --dart-define=USE_EMULATORS=true`, and walk the co-op flow: open The Crew → create a
table → log a WON session on a mission → confirm the board advances and the history row reads
"Team won · Mission N". Then branch + commit, deploy rules/indexes, and run the migration script.

---

# Handover — 2026-07-24

## Current Milestone

Implementing the **tester's feature-gap backlog** (`docs/backlog.md`).
Done to date: **H1–H5, H6a, Q1–Q4, P1, P2, P5, P6, M1–M4** — every backlog item except two infra
items. Also added **Flutter web support** earlier. Remaining: **P3** (Crashlytics/analytics) and
**H6b/P4** (avatar upload — `image_picker` + Storage).

`feat/play-score-and-edit-fixes` was merged into `main` on 2026-07-24 (31 commits, fast-forward,
no conflicts). Future work should branch from `main` again.

### P2 + P5 completed this session (full light-mode migration)

- **New theming system** (`lib/shared/theme/app_colors.dart`): an `AppColors` `ThemeExtension`
  holding the 14 semantic tokens, with `kDarkColors` (legacy look) + `kLightColors` (warm "paper")
  instances, a `context.colors.<token>` accessor, and `buildLightTheme()`/`buildDarkTheme()`.
  `app_theme.dart` is now **just the raw `kColor*` dark palette consts** (kept as the source for
  `kDarkColors`; no more `buildAppTheme`). Import direction is one-way `app_colors → app_theme`.
- **Persisted `ThemeMode`** (`shared/providers/theme_mode_provider.dart`, `StateNotifier` +
  `shared_preferences`, key `themeMode`, defaults to dark). `main.dart` is now a
  `ConsumerStatefulWidget` wiring `theme/darkTheme/themeMode`.
- **Settings screen** (`features/settings/settings_screen.dart`, P5): System/Light/Dark selector +
  About/version (`kAppVersion = '1.0.0'`). Reached via a new **Profile → Settings** row.
- **Migrated all 643 `kColor*` call sites** across 30 files to `context.colors.<token>`, plus the
  15 duplicated `Color(0xFF0A0905)` app-bar hexes → `context.colors.appBarBackground`, so both
  palettes cascade everywhere. `const` was stripped only where a widget now paints a runtime color.
- New l10n keys: `profileSettings`, `settings*`. Each pumped test `MaterialApp` now sets
  `theme: buildDarkTheme()` so `context.colors` resolves. `flutter analyze` clean; `flutter test`
  **91 pass**. Committed in 2 chunks (theme infra + Settings; then the call-site migration).

### H6a completed

- `login_screen.dart`: added a right-aligned **"Forgot password?"** link (sign-in mode only) that
  calls `FirebaseAuth.sendPasswordResetEmail` with the email already typed. Empty/invalid email →
  inline prompt; success → SnackBar; `user-not-found` is treated as success (no account
  enumeration). New l10n keys `authForgotPassword` / `authResetEmailNeeded` / `authResetSent`.
- Test `test/features/auth/login_screen_test.dart`: link visibility (shown in sign-in, hidden in
  register mode) + the empty-email guard (that branch returns before any Firebase call, so it's
  testable without Firebase). The actual send path isn't unit-tested — `login_screen` uses
  `FirebaseAuth.instance` directly (not injected), so it needs the emulator/a device to exercise.
  `flutter analyze` clean; `flutter test` **91 pass**.

### P6 completed / notes

- `CLAUDE.md` feature-dir list corrected: dropped the non-existent `games/` and `sessions/`
  entries (game detail lives in `library/`, play history/detail in `plays/`).
- **Emulator logs**: nothing to do — no `*-debug.log` is tracked (`git ls-files` is clean) and
  `*.log` is already git-ignored. The backlog's claim predates a cleanup or they were never
  committed.
- **`getMyFriends` CF**: confirmed orphaned (app uses the `watchMyFriends` stream; the client
  `FriendRepository.getMyFriends()` has no callers) BUT it's a deployed, jest-tested function.
  Per the audit's "don't delete unasked" and the owner's explicit choice this session, it's
  **left in place, flagged only** — do not remove without a fresh go-ahead + a `firebase deploy`.

### Q4 completed

- `main.dart`: `_useEmulators` is now `bool.fromEnvironment('USE_EMULATORS')` (was a hard-coded
  `false`). Defaults to false → production, so normal runs/builds are unchanged; pass
  `--dart-define=USE_EMULATORS=true` to hit the emulator suite. `CLAUDE.md` gotcha updated.
- `integration_test/app_test.dart`: removed the hard-coded prod account
  (`thisemailcannotexist@gmail.com` / `joeyqwer1!`). Creds now come from `--dart-define`
  (`TEST_EMAIL`/`TEST_PASSWORD`/`TEST_EMAIL2`/`TEST_PASSWORD2`) with throwaway `*.test` defaults
  that the Auth emulator creates on the fly. Added a run-instructions header comment.
- **Not executed here**: running the UI integration test needs the full emulator suite
  (Auth :9099, Functions :5001, Firestore :8080 — with `functions` built) **and** a target
  device/browser, and its Firestore :8080 clashes with the dev web build. `flutter analyze` is
  clean and the unit/widget suite is **89 pass**; the integration run itself is left for a machine
  with the emulator suite + a device. The test's string assertions still match the l10n English
  strings, so no assertion changes were needed.

### Q3 completed

- **Flutter**: `calculateExpeditionScore` (Lost Cities) is now unit-tested; extracted a pure
  `terraformingMarsTotal(...)` from the widget State so Terraforming Mars scoring is testable too,
  and tested it. Both files also have a build-smoke test. (`flutter test` **89 pass**.)
- **Backend (jest, against the Firestore emulator)**: new `functions/test/library.test.ts`
  (listBoardGames — ordering, limit, `` prefix search, blank-search, auth + validation) and
  `functions/test/userSearch.test.ts` (the onCreate/onUpdate triggers). Added `callListBoardGames`
  wrappers to `test/helpers/callables.ts` and `seedBoardGame` to `test/helpers/seed.ts`.
  (`npm test` in `functions/` = **7 suites, 122 tests pass**.)
- **How the trigger tests work**: firebase-functions v2 sets `func.run = handler` (verified in
  `node_modules/.../v2/providers/firestore.js`), so `.run(event)` calls the bare handler — the
  tests pass a minimal `{ params:{userId}, data:{ data()/before/after } }` event, no
  firebase-functions-test needed.

### Running the backend tests (important — port clash)

`npm test` in `functions/` needs the **Firestore emulator on 127.0.0.1:8080** (hard-coded in
`test/envSetup.ts`). The dev **web build also uses 8080**, so only one can run at a time. The
emulator needs Java, which isn't on PATH here — start it with Android Studio's JDK:
`$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; $env:PATH="$env:JAVA_HOME\bin;C:\Users\yujon\AppData\Roaming\npm;$env:PATH"; firebase emulators:start --only firestore --project demo-boardgame-test` (from repo root), then `npm test` in `functions/`.

### M4 completed

- New `lib/features/library/campaign_registry.dart`: `CampaignSpec { int missionCount }` +
  `kCampaignRegistry<gameId, CampaignSpec>` + `campaignForGame(gameId)`. Mirrors the tools
  registry. Registered **both** seeded Crew games — Planet Nine (50 missions) and, newly,
  **Mission Deep Sea (96 missions)**, which previously had no sheet.
- `crew_record_section.dart`: dropped the `kTheCrewPlanetNineGameId` / `kTheCrewMissionCount`
  consts; `CrewRecordSection` and `CrewRecordCard` now take a `missionCount` param (used for the
  clamp, stepper bound, range hint, and denominator) instead of the hard-coded 50.
- `game_detail_page.dart`: the `if (gameId == kTheCrewPlanetNineGameId)` gate is now
  `final campaign = campaignForGame(gameId); if (campaign != null) CrewRecordSection(...,
  missionCount: campaign.missionCount)` — so any registered game gets a sheet.
- Tests: new `campaign_registry_test.dart` (both games' mission counts + null for others);
  `crew_record_card_test.dart` updated to pass `missionCount: 50`. `flutter analyze` clean;
  `flutter test` **78 pass**.
- Note: `CrewCampaign`/`CrewRecordCard` are still Crew-shaped (crew roster + mission). That's fine
  — every seeded campaign game is a Crew game. A genuinely different campaign *type* would need a
  new spec+widget, but that's YAGNI today.
- Not visually confirmed on a device; the running web build needs a hot-restart to show it.

### M3 completed

- New public `MostPlayedSection` widget in `home_tab.dart`: top-5 games by `playCount`, each with
  a bar sized relative to the most-played game (mirrors `library_tab`'s win-rate bar) + the count.
  Inserted as a sliver between the stats row and the "Recent Plays" header; hidden until at least
  one game is logged.
- **No new Firestore read**: sourced from the already-watched `libraryProvider` data (the library
  subcollection carries per-game `playCount`/`winCount`), rather than a separate `gameStats` read.
  `stats/{uid}/gameStats` holds the same per-game counts if a server-sourced version is ever wanted.
- Made `MostPlayedSection` public specifically so it's unit-testable without faking Firebase —
  `test/features/home/most_played_section_test.dart` checks ranking + the top-5 cap + zero-play
  exclusion, and the "renders nothing" empty case. `homeMostPlayed` l10n key added.
  `flutter analyze` clean; `flutter test` **76 pass**.
- Not visually confirmed on a device; the running web build needs a hot-restart to show it.

### M2 completed

- `main_shell.dart` is now a **3-tab** shell (Home, Library, **Friends**): added a `Friends`
  `_NavItem` (`Icons.group`) and `const FriendsScreen(embedded: true)` as the third
  `IndexedStack` child. The add-play FAB is hidden on the Friends tab (`_selectedIndex < 2`).
- `FriendsScreen` gained an **`embedded`** flag: as a tab it hides the back button
  (`automaticallyImplyLeading: false`, `leading: null`); pushed as a route (default
  `embedded: false`, e.g. the Profile → Friends row) it keeps the back button. Nesting its
  Scaffold inside the shell Scaffold is fine — the outer Scaffold already reserves the bottom-nav
  height, so no overlap.
- `navFriends` l10n key added. `flutter analyze` clean; `flutter test` **74 pass**.
- The **Profile → Friends** row still works (pushes the non-embedded FriendsScreen). It's now
  somewhat redundant with the tab — left in place (harmless); remove if you want a single entry.
- Not visually confirmed on a device; the running web build needs a hot-restart to show the tab.

### M1 completed

- New `lib/features/library/catalog_browse_screen.dart` (`CatalogBrowseScreen`) — full-screen
  search over the whole `boardGames` catalog, reusing `gameCatalogProvider` (the same hybrid
  local+remote search that backs the play game-picker). Tapping any game opens `GameDetailPage`
  (works for un-played games: empty history + any registered tools/campaign sheet). Shows a
  `min–max players` subtitle when available. Loading / error / empty states mirror the picker.
- **Entry point**: an explore action (`Icons.travel_explore`) on the **Library** header, not a
  new nav tab — deliberately leaves the shell's 2-tab nav untouched so **M2** can restructure it.
  `ProfileAppBar` gained an optional `trailing` widget (Home passes none; Library passes the
  explore button); its title is now `Expanded` + ellipsis so the action fits.
- Tested via `test/features/library/catalog_browse_screen_test.dart` (fake catalog repo through
  the Q2 `gameCatalogRepositoryProvider`): lists games + player range, and the empty state.
  `flutter analyze` clean; `flutter test` **74 pass**.
- Not visually confirmed on a device (Windows box). The running web build predates this change —
  it needs a hot-restart to show the new screen.

### H4 completed this session

- New `PlayRepository.fetchSharedPlays(friendId, {scanLimit = 100})` — queries the caller's
  recent plays (`participantIds arrayContains uid`, `orderBy playedAt desc`, `limit`) and
  client-filters for the friend's uid. **No rules or index change needed**: the caller is always
  a participant (so the existing `plays` read rule permits it), and the required composite index
  (`participantIds CONTAINS` + `playedAt DESC`) already exists in `firestore.indexes.json` —
  it's the same query shape as `watchRecentPlays`.
- `friend_profile_screen.dart` loads it in `initState` (parallel to the profile) and renders a
  new **"PLAYED TOGETHER"** section (`_SharedPlays` + `_SharedPlayRow`): a "{n} games together"
  count line and a tappable list of shared plays (game + date → `PlayDetailPage`), with
  loading / empty / error states. l10n keys added under the friends group.
- **Head-to-head W/L was deliberately NOT built**: play docs carry no winner info (winners live
  only in the `participants` subcollection), so a true W/L record would need either N per-play
  subcollection reads or a new `winnerIds` field on the play doc + backfill. Shipped the shared
  count instead. If W/L is wanted later, add `winnerIds` in `createPlay.ts`/`updatePlay.ts`.
- Tested via `test/features/friends/friend_profile_screen_test.dart` (fake friend+play repos,
  overridden through the Q2 providers): asserts the count header + rows render, and the empty
  state. `flutter analyze` clean; `flutter test` **72 pass**.
- **UI not visually confirmed on a device** — this is a Windows dev box with no iOS/Android
  simulator; the widget test covers the section's render + empty state instead.

### P1 completed this session (full `flutter_localizations` + ARB, per owner's choice)

- **Infrastructure**: added `flutter_localizations` + `intl` and `generate: true` to
  `pubspec.yaml`; new `l10n.yaml` (arb-dir `lib/l10n`, output class **`AppStrings`**,
  `nullable-getter: false`). Template `lib/l10n/app_en.arb` holds all keys. Generated
  `lib/l10n/app_localizations*.dart` is **git-ignored** (regenerated by `flutter gen-l10n` /
  `flutter pub get`). `main.dart` wires `AppStrings.localizationsDelegates` /
  `supportedLocales` and `onGenerateTitle`.
- **Migrated every user-facing string** in: `main.dart`, **auth** (login, profile_setup,
  profile), **shell** (main_shell), **home** (home_tab), **library** (library_tab,
  game_detail_page, crew_record_section), **friends** (friends_screen, friend_requests_screen,
  friend_profile_screen), **plays** (all 10 files), **shared/widgets** (game_picker_sheet;
  profile_app_bar had no literals), and the **tool registry** (game_tools_registry + tool_card
  + GameTool model).
- **ICU plurals / placeholders** used where the code hand-rolled them: `playsCount`,
  `playersCount`, `playersCountCaps`, `gamesCount`, `sessionsCount`, the relative-time set
  (`timeYearsAgo`…`timeJustNow`), `friendGameStat`, `minPlayersNeeded`, `playersCountMax`, etc.
- **Notifier refactor (design)**: `AddPlayNotifier`/`AddPlayState` no longer expose display
  strings. `saveButtonText`/`addButtonText`/`playerCountText` were **replaced** by data getters
  `belowMinPlayers`, `effectiveMinPlayers`, `maxPlayers` (+ existing `canAddParticipant`);
  `add_play_screen.dart` now composes those strings via `AppStrings`. This keeps copy out of
  business logic. `add_play_notifier_test.dart` was updated to assert the data getters.
- **GameTool resolver pattern**: `GameTool.title`/`.description` changed from `String` to
  `String Function(AppStrings)` so the top-level `kGameToolsRegistry` (built without a
  BuildContext) can localize at render time; `tool_card.dart` calls `tool.title(AppStrings.of(context))`.
- **Test fixes**: added `AppStrings.localizationsDelegates`/`supportedLocales` to the
  `MaterialApp` in `crew_record_card_test.dart`, `play_history_page_test.dart`, and
  `add_play_screen_test.dart` (their pumped widgets now call `AppStrings.of(context)`).

### Verification done

- `flutter analyze` **clean**; `flutter test` **70 pass**. (Interactive simulator tap-through
  not re-run this session — changes are string-for-string swaps behind the analyzer + the
  existing widget tests, which pump the real screens.)
- Committed in logical chunks on branch `feat/play-score-and-edit-fixes` (auth; shell/home/
  library; friends; plays; game picker; tool registry).

## Context & Decisions

- **Owner chose full l10n (ARB)** over a lighter constants file — so translations can be added
  later by dropping in `app_xx.arb`. Only `en` exists today.
- **Generated l10n is git-ignored** (produced on `pub get`/`gen-l10n`); CI must run one of those
  before analyze/test. If you'd rather commit it, drop the `.gitignore` line.
- **Month abbreviations** in the various `_formatDate` helpers were intentionally left as-is —
  they're date-formatting data, not UI copy. If true locale-aware dates are wanted, switch those
  to `intl`'s `DateFormat` (separate, behavior-changing task).
- A per-edit `flutter analyze` hook runs on save; keep it green.

### Calculators completed (this session, closing P1)

- All 5 score calculators are now localized. The `enum … label`-String pattern was replaced with
  a **resolver extension** (closures can't live in const enum constructors): the enum values are
  now bare, and a `extension XL10n on X { String label(AppStrings s) => switch(this){…} }`
  resolves them; row widgets call `category.label(AppStrings.of(context))`. See
  `seven_wonders_duel/score_row.dart`, `wingspan_calculator_screen.dart`,
  `seven_wonders/seven_wonders_calculator_screen.dart`.
- Lost Cities' const expedition list dropped its `title` strings; titles are now resolved in
  `build` (`[s.lostCitiesGold, …]`) parallel to a const color list.
- Shared calculator keys: `calcReset/Total/GrandTotal/Players/Showing/Category/Player1/Player2/
  Tie`, plus placeholder helpers `calcPlayerWins(n)`, `calcPlayerWinsTiebreaker(n)`,
  `calcTieMulti(players)`, `calcPlayerChip(n,total)`, `calcPlayerTotal(n)`. The `'P'` prefix in
  the "P1 · P2" tie string is left as a plain glyph (like `#rank`).
- The five calculator tests (`widget_test.dart`, `wingspan/seven_wonders/seven_wonders_duel`
  `_calculator_test.dart`) got `AppStrings.localizationsDelegates`/`supportedLocales` added to
  their pumped `MaterialApp`; asserted strings are unchanged so no assertion edits were needed.

## The 'Gravel' (non-obvious findings)

- **P1 is fully done** — no hardcoded UI strings remain anywhere in `lib/` (verified by grep).
  New UI (like H4's section) should keep using `AppStrings`.
- The friend profile is still a **one-shot `Future`** loaded in `initState` (both the profile and
  now the shared plays) — no live refresh. Left as-is to match the existing pattern; make it
  a stream if live updates are wanted.
- Month abbreviations in `_formatDate` helpers were intentionally left as-is (date data, not UI
  copy). Switch to `intl`'s `DateFormat` if true locale-aware dates are ever wanted.
- `rank` is still never set by the client (scores entered, ranks not derived). (from H1)
- **Theming (P2) gravel:**
  - All screen colors now go through `context.colors.<token>` — **new UI must use it, not the raw
    `kColor*` consts** (those remain only to seed `kDarkColors`). Adding a color means adding a
    field to `AppColors` (+ `copyWith`/`lerp`) and to both palette instances.
  - The 643-site migration was mechanical (sed for the name+import swap; a scratch Python script
    stripped the nearest enclosing `const` per `invalid_constant` until analyze was clean). `const`
    is therefore gone from every widget that paints a runtime color — that's inherent to runtime
    theming and trades against CLAUDE.md's "const everywhere" rule; theming wins where they meet.
  - **Light `primary` is a deep bronze (`0xFF7A5E0A`), not the dark theme's bright gold.** Primary
    doubles as accent-text *and* button-fill; bronze stays legible as text on the cream background
    while white `onPrimary` reads on the bronze fill. If you retune, keep both roles legible.
  - **Follow-up sweep (same session)**: several hand-rolled colors outside the 643 `kColor*` sites
    were missed by the mechanical migration because they were plain hex literals, not tokens.
    Fixed: `library_tab.dart`'s six-color card-swatch gradient (added a light-mode tint palette,
    picked by `Theme.of(context).brightness`) and its win-rate bar track; `home_tab.dart`'s
    matching play-volume bar track (both moved to `context.colors.outlineVariant`); the whole Lost
    Cities calculator (`expedition_column.dart` panel/number-button fills → `context.colors`,
    negative-score red → `colorScheme.error`); the Lost Cities suit palette and Terraforming
    Mars's `_marsRed` accent (both gained a deepened light-mode variant, brightness-selected —
    the bright originals were ~1.7–3.5:1 on the paper background); and the add-FAB's outer glow
    in `main_shell.dart` (now `context.colors.primary.withAlpha(26)` instead of a hardcoded gold).
    Net effect: **no color in the app is hardcoded-fixed anymore** — every brand accent that used
    to be a single value is now a light/dark pair selected by `Theme.of(context).brightness`.
  - **Verified theme-clean**: Seven Wonders (classic + Duel) and Wingspan calculators had zero
    hardcoded colors — they render entirely through the shared `presentation/widgets/
    calculator_widgets.dart`, which was already theme-aware.
  - Status-bar icon brightness follows the theme via each `ThemeData`'s
    `appBarTheme.systemOverlayStyle` (light/dark). `main.dart` still calls
    `SystemChrome.setSystemUIOverlayStyle(... light)` once at startup — harmless, the appbar theme
    overrides it per-screen.

## Next Immediate Step

Only infra/polish remains, in rough value order:

- **P3** — Crashlytics first, then analytics for key funnels (login, add-play, add-friend).
- **H6b / P4** — avatar upload for email/password users: `image_picker` + Firebase Storage
  (currently `photoUrl` only ever comes from Google). Charts (would enrich the M3 leaderboard)
  are also gated on a chart package.

Recommended next: **P3** (Crashlytics) — highest value for a shipping app.
