# Handover — 2026-07-24

## Current Milestone

Implementing the **tester's feature-gap backlog** (`docs/backlog.md`).
Done to date: **H1–H5, H6a, Q1–Q4, P1, P6, M1–M4**, and now **P2 + P5 — light theme + persisted
theme switch + Settings screen**. Also added **Flutter web support** earlier. Remaining:
**P3** (Crashlytics/analytics) and **H6b/P4** (avatar upload — `image_picker` + Storage).

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
  - Lost Cities' expedition accent list (`Color(0xFFF2CA50)` etc. in `lost_cities_calculator_screen`)
    is a **context-less brand palette, deliberately left fixed** — it does not theme-switch.
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
