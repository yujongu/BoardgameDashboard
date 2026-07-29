# Handover — 2026-07-29 (session: D12 campaign membership)

## Current Milestone

**Fixed D12 / plan 1.4 — two people could not share one campaign table.** Product call
taken by the owner this session: **a table's participants are fixed at creation**, every
participant sees the table and can log sessions against it, and guests (people with no
account) are allowed as display-only seats.

Status: **implemented; `flutter analyze` clean; `flutter test` 309 pass. NOT committed, rules
NOT deployed, production `campaigns` NOT yet wiped** (see Next Immediate Step).

## Context & Decisions (this session)

- **Root cause was never `createPlay`.** Its membership gate (`createPlay.ts:149`) was
  already the right check; it failed only because creation wrote the wrong `memberIds`.
  **No Cloud Function change was needed** — `functions/` is untouched.
- **`roster` is gone, replaced by `participants: List<CampaignMember>`** where
  `CampaignMember = {name, userId?}` and a null `userId` is a guest. The old model kept
  `roster` (names) and `memberIds` (uids) as **unpaired parallel lists**, so there was no way
  to tell which name belonged to which uid — impossible to auto-fill a play's participants
  from a table. `memberIds` survives as a denormalized uid list because Firestore rules and
  `array-contains` cannot reach into a map inside an array.
- **Immutability is enforced in rules, not just UI**: the `campaigns` `allow update` now
  requires `memberIds` and `participants` to be unchanged. `allow delete` is unchanged.
  `saveCampaign` was narrowed to write only `stages`/`updatedAt` to match.
- **One creation flow for both entry points**: new `lib/features/library/new_table_sheet.dart`
  (`showNewTableSheet`) collects the seat list once, reusing `ParticipantPickerBottomSheet`
  (which already supports guests). Game Detail's `_newTable` and Add Play's `_createTable`
  both call it. The old Add Play path snapshotted `state.participants` at creation — under
  immutability that ordering trap would lock people out permanently, so seats are now
  collected explicitly.
- **`AddPlayNotifier.setCampaign` now also seats the play** with the table's participants, and
  the Add Play list goes read-only (`seatedAtTable`): no add button, no remove, names locked.

## The 'Gravel' (non-obvious)

- **`_controllers` / `_scoreControllers` must be rebuilt whenever `setCampaign` runs** — the
  invariant at `add_play_screen.dart:33` is that they stay index-aligned with
  `state.participants`, and `setCampaign` now replaces that list wholesale. All three call
  sites go through `_applyCampaignParticipants`, which disposes and rebuilds them. Calling
  `setCampaign` directly from the screen will silently desync the text fields.
- **Three `campaign_card_test.dart` tests were deleted, not fixed** — they asserted the
  roster add-dialog and chip-removal behaviour that the policy removes. Replaced by one
  `crew list is read-only` test. Suite went 309 → 307 → 309 with the two new notifier tests.
- **Generated l10n went stale on the pull** and again mid-session: `flutter gen-l10n` must be
  re-run after editing `app_en.arb`, and the errors it produces (`undefined_getter` on
  `AppStrings`) look like source errors but are not. Five new `table*` keys were added.
- **UI NOT visually confirmed** — this is a Windows box with no iOS/Android simulator, so the
  new-table sheet and the locked participant list have not been seen rendered. The widget
  tests pump the card with the production theme, but nothing has exercised
  `showNewTableSheet` on a device.
- **Existing production tables are now unreadable-by-design**: docs written before this change
  have no `participants` field, so the card renders an empty crew list. That is why the wipe
  below is not optional.

## Post-implementation ops (done this session)

- **Rules deployed** to prod `gameshelf-283dc` — the immutability guard is live.
- **Production `campaigns` wiped**: all 3 docs deleted, collection now empty. Two were
  empty test tables; the third (`0aUvVDBRgLSarJxbXw0b`) held **10 completed missions and
  12 logged sessions** of real Crew progress. That was surfaced before deleting and the
  owner confirmed the wipe anyway. A JSON backup of all three docs was written first, to
  the session scratchpad — **that path is temporary and will not survive**; copy it
  somewhere durable if the progress is ever wanted back.
- **Committed** on branch `fix/campaign-membership` (`188f9fe`), 12 files. Not merged, not
  pushed. `pubspec.lock` (transitive `meta`/`test_api` bumps from the analyze hook's
  `pub get`) and the generated macos plugin registrant were deliberately left out.
- Useful fact found while checking: **예진 has no account** — the only registered users are
  정우 (the owner), Avik Abdula, and two test accounts. So on a rebuilt table 예진 is a
  guest seat, which is exactly what the new model expects.

## Next Immediate Step

**Device pass — the actual D12 scenario, which no test covers**: create a table with a
registered friend plus a guest, then confirm from the *friend's* account that the table
appears on their Game Detail and that they can log a session against it. That round trip
is the whole point of the fix and has never been executed against production.

Then rebuild the wiped Crew table (10 missions can be re-entered through the board card's
"Correct Mission N" editor), merge, and ship a build — note the client fixes from the
previous session are still unreleased too, so one release covers both.

---

# Handover — 2026-07-29 (session: production smoke test)

## Current Milestone

**Ran the production smoke test** from the previous session's checklist (see that section
below, now marked ☑). **Part A and Part B both passed in full — 7/7 Part B checks green.**
This closes the last open item from the Part 1 defect sweep: the D1–D13 fixes are now
confirmed working against production, not just the emulator.

- **Part A** (deployed backend, existing app build): play loads with participants, edit saves,
  competitive play moves PLAYS + WINS, delete drops the counts, co-op play writes
  `totalCoopPlays` without touching `totalGamesPlayed`/`library.playCount`, rename propagates
  to a friend's list (D11).
- **Part B** (client fixes, production build from `main`): D6 Lost Cities scores 41, D5 save
  bar blocks the over-cap play, D4 shows "Added" in the Edit picker, D9 history row disappears
  after delete, D10 table picker scrolls to "New table", D13 "Correct Mission N" opens the
  editor, D2 offline delete surfaces an error and the play survives.

## Context & Decisions (this session)

- Verification only — **no code changed, nothing to commit.** `main` is unchanged at `9e8233f`.
- Part B needed a production build (**no `--dart-define=USE_EMULATORS=true`**, or it retests the
  emulator). `main.dart` defaults the define to false, so plain release flags hit production.

## The 'Gravel' (non-obvious)

- **The client fixes are verified but still not *released*.** Part B was run from a local build
  off `main`; no artifact has shipped to any store or tester. Anyone on an older build still has
  D2/D4/D5/D6/D9/D10/D13. Cutting a release is the natural follow-up.
- Part B writes to **production Firestore on a real account** — the plays logged during the run
  are real. Delete any leftovers if they were not cleaned up during the pass.
- **D7 (same-day play ordering) was not in the checklist** and remains unverified in production.
  It is slow to observe: log two plays minutes apart the same day, tapping today in the date
  picker on the second, then confirm the newer sorts on top.
- **D5 residual is still live**: `EditPlayPage` holds only `gameId`/`gameName`, so *editing* a
  play can still exceed the player cap. Known and out of scope — not a smoke-test failure.

## Next Immediate Step

The smoke test is closed, so the queue is now the item-2 backlog in the section below. In
value order: **cut and ship a release build** (the client fixes are verified but unreleased),
then **D12 / plan 1.4 — campaign membership**, the highest-value unfixed defect: two people
still cannot share one campaign board (`createPlay` never adds participants to `memberIds`, and
`campaign_record_section.dart:76` disagrees with `add_play_screen.dart:184`). It needs a product
call first — should logging a session imply joining the table?

---

# Handover — 2026-07-28 (session: manual test plan, Part 1 execution)

## Current Milestone

**Executed `docs/manual-test-plan.md` Part 1 (the 16 targeted defect repros)** against two
iOS simulators + the Firebase emulator suite, then **fixed every confirmed defect**.

Result: **14 of 16 confirmed → all 14 fixed**; 1.12 is not a defect; 1.16 appears already
fixed but is not runnable here (no Android AVD). No production data touched — everything ran
against the emulator suite.

Full write-up with repro steps, evidence and fix pointers: **`docs/defects.md`** (D1–D13).

Merged to `main` via `--no-ff` (`0c9ed28`) and **pushed to `origin/main`**, so the 11 commits
stay individually reviewable and revertible. Suites at the end of the session:
`flutter analyze` clean, **309 Dart tests**, **156 functions tests** (from 292 / 132).

**Deployed to production 2026-07-29** (`firebase deploy --only functions`). Verified against
source: 17 exported functions, 17 deployed, no orphans, and `deletePlay` / `updatePlay` /
`getPlay` all carry the D1 authorization fix. **The D1 hole is closed in production.**

The deploy also removed `getFriendProfile`, a function that existed in the project but not in
source — dead since the friend profile moved to `getFriendProfileDirect` (three direct
Firestore reads guarded by the `isFriendOf` rule). Confirmed unreferenced before deleting: it
is absent from `functions/src`, and the client's `httpsCallable` names do not include it.

No rules or index deploy was needed — `firestore.rules` was already correct; the gap was that
callables bypass it.

| # | Item | Verdict |
|---|------|---------|
| 1.1 | Home PLAYS count vs Recent Plays list (co-op) | **CONFIRMED — ✅ FIXED** |
| 1.2 | Deleting a co-op play corrupts lifetime stats | **CONFIRMED — ✅ FIXED** |
| 1.3 | Deleting a co-op play does not rewind the campaign board | **CONFIRMED — ✅ FIXED (undo added; latch intended)** |
| 1.4 | No way to join someone else's campaign table | **CONFIRMED — worse than documented — NOT FIXED** |
| 1.5 | Edit Play can add an already-present participant | **CONFIRMED — ✅ FIXED** |
| 1.6 | A play can exceed the game's max players | **CONFIRMED — ✅ FIXED (Add Play; Edit residual)** |
| 1.7 | Play History keeps a play after deletion | **CONFIRMED — ✅ FIXED** |
| 1.8 | Delete failures are silent | **CONFIRMED — ✅ FIXED** |
| 1.9 | Lost Cities wagers don't count toward the 8-card bonus | **CONFIRMED — ✅ FIXED** |
| 1.10 | Friends' names go stale after a rename | **CONFIRMED — ✅ FIXED** |
| 1.11 | Table picker sheet overflows with many tables | **CONFIRMED (360px overflow) — ✅ FIXED** |
| 1.12 | Stage stepper impractical for Gloomhaven | **NOT A DEFECT — tap-to-type works** |
| 1.13 | Any signed-in user can edit/delete any play | **CONFIRMED — most severe — ✅ FIXED** |
| 1.14 | Non-friends can be added as participants | **CONFIRMED — NOT FIXED (product call)** |
| 1.15 | Same-day ordering looks wrong | **CONFIRMED — ✅ FIXED** |
| 1.16 | Status bar style hardcoded for dark | **Appears already fixed (code-level only)** |

## Context & Decisions (this session)

- **Test rig**: two booted simulators (iPhone 17 Pro = Alice, iPhone 17 = Bob), app built
  once with `flutter build ios --simulator --debug --dart-define=USE_EMULATORS=true` and
  `simctl install`ed on both. UI driven by **idb** (`brew install idb-companion` + `fb-idb`
  in a venv). This required `brew trust facebook/fb` — Homebrew now gates third-party taps.
- **fb-idb 1.1.7 is incompatible with Python 3.14** (`asyncio.get_event_loop()` no longer
  auto-creates a loop). Worked around with a 3-line shim that calls
  `asyncio.set_event_loop(asyncio.new_event_loop())` before `idb.cli.main`. If idb is
  adopted for CI, pin Python ≤3.12 instead.
- **Driving strategy**: `idb ui describe-all` returns the accessibility tree, so taps target
  elements by label rather than pixel coordinates. Far more robust than screenshot math.
- **Rebuilding the rig next session.** `idb_companion` survives (installed via brew), but the
  Python venv and the driver scripts lived in the session scratchpad and are **gone**. To redo
  simulator work: `python3 -m venv <dir> && <dir>/bin/pip install fb-idb`, add the
  event-loop shim above, then drive with `describe-all` → find label → `ui tap x y`. Useful
  details learned the hard way: match button labels **exactly** (a substring match on
  "Sign In" hits "Sign in to continue"); a `Switch` shows up as a `CheckBox` in the tree and
  the tap must land inside its frame; and `xcrun simctl keychain <udid> reset` is the only way
  to clear a persisted Firebase Auth session.
- **Seeding test accounts**: `admin.auth().createUser({uid: ...})` against the Auth emulator
  gives stable uids across restarts, which matters because the app caches the session. Write
  **both** `name` and `displayName` on `users/{uid}` (see the gotcha below).
- **Data-layer defects (1.2, 1.3, 1.4, 1.5, 1.13, 1.14) were proven by calling the emulated
  callables directly** (node + `fetch` with an Auth-emulator ID token) and reading Firestore,
  rather than through the UI. That gives exact before/after numbers instead of inference.
- 1.8 was reproduced by killing **only** the Functions emulator (port 5001) so Firestore
  stayed up — a closer analogue to "delete fails" than full airplane mode.

## The 'Gravel' (non-obvious findings)

> This section is the **as-found evidence record**, written during testing and left unedited.
> Its recommendations ("fix this first", "should be X") describe what was true *before* the
> fixes — every item below except 1.4, 1.14 and 1.16 has since been fixed; see the FIXED
> sections that follow. Kept verbatim because the observed numbers are the proof, and the next
> person may want to reproduce them.

- **1.13 is the one to fix first.** `deletePlay`/`updatePlay` check `request.auth` but never
  that the caller is a participant or the creator. Verified: account C (not in the play,
  not a friend) called `updatePlay` **and** `deletePlay` on an A+B play — both returned 200
  and the play was destroyed. Firestore rules don't help; the Admin SDK bypasses them.
- **1.4 is worse than the plan states.** `memberIds` is never updated by `createPlay`, so B
  not only can't *see* A's table — B gets `403 PERMISSION_DENIED "Only campaign members may
  log sessions."` if they try to log to it. Note the two creation paths disagree:
  `campaign_record_section.dart:76` passes `memberIds: const []` (Game Detail → New table,
  creator only), while `add_play_screen.dart:184` derives members from the participant list.
- **1.2 breaks the Part 8 invariant measurably**: after one competitive play + one co-op play
  + deleting the co-op play, `stats/{uid}.totalGamesPlayed` = 0 while
  `sum(library.playCount)` = 1. A second sequence produced `totalWins` (2) >
  `totalGamesPlayed` (1) — an impossible state.
- **1.9 loses exactly 20 points** whenever an expedition reaches 8 cards *including* wagers,
  because the bonus is added after the multiplier. Confirmed in the UI: 2 handshakes +
  cards 2–7 scores **21**, rulebook says **41**. `selectedNumbers.length >= 8` should be
  `selectedNumbers.length + handshakeCount >= 8` (`expedition_column.dart:16`).
- **1.12 should be struck from the plan** — tapping the mission number opens a "Mission"
  dialog with a 1–50 range hint, and out-of-range input (999) clamps to 50 correctly.
- **1.16 looks already fixed** by the P2 theming work: `appBarTheme.systemOverlayStyle`
  switches light/dark (`app_colors.dart:230`) and `ProfileAppBar` is a `SliverAppBar`, so
  the tab screens inherit it. The `SystemChrome.setSystemUIOverlayStyle(...light)` call at
  `main.dart:79` is a harmless leftover. **Not empirically verified — no Android AVD exists
  on this machine** (`flutter emulators` lists only the iOS simulator).
- **Incidental (not in Part 1)**: every icon-only control exposes `AXLabel = None` — the
  add-play FAB, the winner trophy, and the remove ×. That is the Part 8 VoiceOver item
  failing; worth fixing alongside 1.13.
- **Gotcha for future rig scripts**: the callables read `users/{uid}.name`, but the field is
  easy to confuse with `displayName`. Seeding only `displayName` makes `sendFriendRequest`
  fail with `FAILED_PRECONDITION "Your profile is missing a name."`.
- Firebase Auth state lives in the **simulator keychain and survives app uninstall** — use
  `xcrun simctl keychain <udid> reset` to force a clean login.
- `idb ui text` silently drops characters on long strings; feed input in ≤8-char chunks and
  read the field back via the accessibility tree to verify.

## D1 / 1.13 — FIXED this session

Policy chosen by the owner: **any registered participant** may read, edit, or delete a play.

- New `functions/src/shared/auth.ts` exports `assertParticipant(play, uid)`, throwing
  `permission-denied` when `uid` is not in `play.participantIds`. The file carries the
  rationale (why rules don't cover callables) so the next reader doesn't have to re-derive it.
- Applied in `deletePlay.ts`, `updatePlay.ts`, **and `reads/getPlay.ts`** — the read side had
  the same hole, which the test plan didn't list. Each call sits after the doc is loaded and
  confirmed to exist, so `not-found` still precedes `permission-denied`, and `deletePlay`
  keeps its idempotent early return.
- `uid` is captured **before** the `runTransaction` closure in delete/update; TypeScript loses
  the `request.auth` narrowing inside the async callback otherwise.
- Tests: `functions/test/playAuthorization.test.ts`, 14 cases. **Full suite 146 passed.**
  Confirmed the tests actually bite — neutering the guard fails exactly the 6 "denies" cases
  while the 8 positive-path cases still pass.
- Re-verified end-to-end on the emulator: stranger → `403 PERMISSION_DENIED` on getPlay,
  updatePlay and deletePlay; non-creator participant → all three succeed.
- **No client change needed.** `getPlay` is only reached from the user's own play lists, and
  `fetchSharedPlays` queries `participantIds arrayContains uid`, so nothing legitimate relied
  on the old behaviour.

## Build-artifact changes (decided: keep all, revert nothing — now committed)

Three files changed as a by-product of running `flutter build ios`. They were reviewed
individually rather than reverted wholesale, and are in `7cddb76`:

- **`ios/Podfile.lock` + `macos/Flutter/GeneratedPluginRegistrant.swift` — keep; these are the
  missing iOS/macOS half of P3.** `pubspec.yaml` has `firebase_crashlytics` / `firebase_analytics`
  committed (`aa1476b`), but both generated files were last touched in `8add70e`, *before* P3 —
  that session verified with `flutter build apk --debug`, which never regenerates iOS/macOS
  artifacts. The registrant now registers `FirebaseAnalyticsPlugin` and
  `FLTFirebaseCrashlyticsPlugin`; the pods lock gains Firebase/Analytics + Firebase/Crashlytics
  11.15.0. Reverting would leave Crashlytics and Analytics declared in Dart but never
  initialized natively on iOS/macOS. This closes the "Device/Mac-only verification still
  outstanding" note from the P3 handover.
- **`pubspec.lock` — keep; it cannot be meaningfully reverted on this machine.** `meta`
  1.18.0 → 1.17.0 and `test_api` 0.7.11 → 0.7.10 are pinned by the Flutter SDK. Verified
  empirically: reverting the file and running `flutter pub get` reproduces a byte-identical
  result. The committed lockfile was generated by a **newer Flutter** than this machine's
  **3.41.7 / Dart 3.11.5**.
- **Verified green on the downgrade**: `flutter analyze` clean, `flutter test` **292 passed**,
  `npm test` in `functions/` **146 passed**.

**Decision on the SDK divergence: do nothing.** Anyone on a newer Flutter will flip those four
lines back, but the packages are test-only transitives with no functional impact. Adding `fvm`
or a `.flutter-version` file is not worth the ceremony for a single-developer repo — revisit
only if a second machine or CI starts building this project, at which point pin the SDK
properly rather than chasing the lockfile.

## D3 + D6 — also FIXED this session

- **D6 (Lost Cities, `expedition_column.dart:17`)**: the bonus condition is now
  `selectedNumbers.length + handshakeCount >= 8`. Wagers are cards by the rulebook, so any
  expedition reaching 8 cards *with* a wager was silently losing exactly 20 points (the bonus
  is added after the multiplier, so the loss is flat). Three regression cases cover the
  boundary at 0–3 wagers plus the 7-card negative case. **Verified in the simulator**: the
  same taps that scored 21 now score 41.
- **D3 (`deletePlay.ts`)**: reads `mode` and skips the derived-data rollback for co-op,
  mirroring `createPlay`'s `if (coop || p.userId === null) continue;`. Implemented by leaving
  the aggregate map empty, so no derived refs are built, `tx.getAll` is skipped, and the
  rollback loop no-ops — the play doc and participant docs are still deleted. Four regression
  cases in a new `deletePlay (cooperative)` block. **Verified on the emulator**:
  `totalGamesPlayed` and `library.playCount` unchanged across a co-op create *and* delete.
- Both fixes were confirmed to be genuinely pinned by their tests — reverting each fails
  exactly the new positive cases and nothing else.
- Suites after both: `flutter analyze` clean, **295 Dart tests**, **150 functions tests**.

## D4 + D5 — also FIXED this session

- **D4 (duplicate participant), server**: `assertNoDuplicateParticipants` in `shared/auth.ts`
  rejects a repeated registered `userId` from `createPlay`/`updatePlay` with
  `invalid-argument`. Guests are **deliberately exempt** — `userId` is null, they have no
  derived data, and Part 3 of the test plan expects two same-named guests to be allowed.
- **D4, client — this was the real root cause**: `ParticipantListSection` read
  `addPlayProvider` for both its "Added" marks *and* its at-max notice, even when the sheet
  was opened from Edit Play. A shared widget with a hidden dependency on one of its two
  callers' state. Both it and `ParticipantPickerBottomSheet` now take `addedUserIds` and
  `atMax` as **required** parameters; the provider import is gone. Add Play wraps the sheet in
  a `Consumer` and Edit in a `StatefulBuilder` so both keep updating live as players are added
  — without that, a *newly* added player would go unmarked and could be added twice again.
- **D5 (max players)**: `canSave` now rejects `participants.length > _effectiveMax`, with a
  new `aboveMaxPlayers` flag driving the save-bar label ("Remove N to fit M players", new
  `maxPlayersExceeded` l10n key — run `flutter gen-l10n` after touching the arb).
  Participants are **not** pruned on game switch: an existing test pins that behaviour, and
  silently deleting entered players is worse than blocking the save.
- **Known residual on D5**: `EditPlayPage` holds only `gameId`/`gameName`, not min/max, so it
  cannot evaluate the cap and passes `atMax: false`. Editing a play can still exceed the
  maximum. Fixing it means resolving the catalog game in the edit page — recorded in
  `docs/defects.md` D5 rather than left silent.
- Both guards verified to bite: neutering each fails exactly its new cases.
- **Verified in the simulator**: the Edit picker now shows `Bob · Added` (was plain `Bob`) and
  tapping him adds no row; switching a 6-player play to 7 Wonders Duel shows
  "Remove 4 to fit 2 players" and the save bar is inert. Live emulator: `updatePlay` with a
  duplicate returns `400 INVALID_ARGUMENT` and leaves `participantCount` at 2; a play with two
  guests named "Sam" still returns 200.
- Suites after both: `flutter analyze` clean, **300 Dart tests**, **153 functions tests**.

## D2, D7, D8, D9, D10, D11, D13 — the remainder, all FIXED

Two needed a product decision, both taken by the owner:

- **D8 / 1.1 — co-op counts toward PLAYS, never toward the win rate.** Added
  `stats/{uid}.totalCoopPlays`, written by `createPlay` and rolled back by `deletePlay`.
  Deliberately a **separate field** rather than folding into `totalGamesPlayed`, so the
  invariant `totalGamesPlayed === sum(library.playCount)` still holds. Client reads it via the
  new `coopPlayCountProvider`; absent fields read as 0. **Not backfilled** — co-op plays logged
  before this commit are uncounted. Verified live: PLAYS 6 → 7 after logging a co-op *loss*,
  win rate unmoved at 100%.
- **D13 / 1.3 — the latch is intended, so `deletePlay` still does not rewind the board.** What
  was missing was the undo. The board card gained a "Correct Mission N" action for the last
  completed stage. Note an editor already existed for this — `_EditMissionDialog` in
  `add_play_screen.dart` — but only inside the Add-Play flow; it is now extracted to
  `lib/features/library/edit_mission_dialog.dart` and shared. The ± stepper could already
  un-complete a *run* of stages but preserves their tries; only this dialog can correct those.

The rest were client-side:

- **D9 / 1.7** — Play History refetches on the boolean the detail route pops.
- **D2 / 1.8** — delete is awaited with a spinner, disabled button, and a failure snackbar.
  Goes through `playRepositoryProvider`, not `playDetailProvider`: popping disposes that
  notifier, which is exactly why the result was discarded before.
- **D10 / 1.11** — table picker is `isScrollControlled`, capped at 70% height, scrollable.
- **D7 / 1.15** — picking a date preserves the current time-of-day instead of midnight.
- **D11 / 1.10** — `getMyFriends` resolves live profiles in one batched `getAll`. **This
  reverses a documented decision** in that function ("intentionally avoids joins ... to
  minimize reads"); one batched read on a list of tens is a better trade than a wrong name, and
  resolving on read repairs already-stale docs without a migration or a new collection-group
  index. The same snapshot pattern still exists on **pending friend-request cards**.

Suites: `flutter analyze` clean, **309 Dart tests**, **156 functions tests**.

## Next Immediate Step

All 14 confirmed Part 1 defects are fixed, merged, and **deployed**. **Start here:**

### 1. ☑ SMOKE TEST PRODUCTION — **DONE 2026-07-29** (see the top session)

> Both parts passed manually against production. The checklist below is kept as the record of
> what was covered; do not re-run it unless the backend is redeployed.

**Why it was open:** the deploy added *new denials* to live traffic and no real account has
exercised them. It could not be done from the test rig — that build is pinned to the emulators
via `--dart-define=USE_EMULATORS=true`, and the probe accounts exist only in the Auth emulator.
Everything verified so far was emulator-side or a deployment-inventory check, **never
production behaviour**.

**Only half the fixes are live.** `firebase deploy --only functions` shipped the *server* half.
Every client fix is still sitting in `main`, unreleased, until a new app build ships:

| Live now (deployed functions) | Needs an app build |
|---|---|
| D1 authorization, D3 co-op rollback, D4 duplicate rejection (server), D8 `totalCoopPlays` writes, D11 friend-name join | D2 delete errors, D4 "Added" marks, D5 max players, D6 Lost Cities, D7 date ordering, D8 Home PLAYS display, D9 history refresh, D10 table picker, D13 board undo |

So run **Part A on the app you already have installed** (it exercises the deployed backend), and
Part B only after `flutter build ios --release` / `flutter build apk --release` — note **no**
`USE_EMULATORS` define, or you will be testing the emulator again.

#### Part A — deployed backend, works with the current app build

- [ ] Open a play you are part of → loads with participants (not "Could not load players").
- [ ] Edit that play, change the notes → saves.
- [ ] Log a new competitive play with a friend → saves; Home PLAYS and WINS both move.
- [ ] Delete a play → it disappears and the counts drop. **Note the PLAYS number first** so you
      can confirm it actually moved.
- [ ] Log a **co-op** play (Pandemic or The Crew) → saves. Its PLAYS contribution will not show
      until Part B, but `stats/{uid}.totalCoopPlays` should be 1 in the Firestore console.
- [ ] Delete that co-op play → in the console, `totalGamesPlayed` and every `library.playCount`
      must be **unchanged** (this is D3; it used to corrupt them), and `totalCoopPlays` back to 0.
- [ ] Rename yourself in Profile → Edit, then have a friend reopen their Friends tab → they see
      the **new** name (D11).

#### Part B — client fixes, after shipping a new app build

- [ ] Lost Cities calculator: 2 handshakes + cards 2–7 → scores **41**, not 21 (D6).
- [ ] Add Play → 6 players, switch the game to 7 Wonders Duel → save bar reads
      "Remove 4 to fit 2 players" and is inert (D5).
- [ ] Edit a play → "+ Add player" → an existing participant shows **Added** and is not
      tappable (D4).
- [ ] Home → See all → open a play → delete → back → the row is **gone** (D9).
- [ ] A game with 8+ tables → Add Play → Table → the list scrolls and "New table" is reachable
      (D10).
- [ ] Game Detail → a campaign table past mission 1 → "Correct Mission N" opens the editor (D13).
- [ ] Airplane mode → delete a play → an error snackbar appears, and the play survives (D2).

#### If something fails

Server: `git revert e568be4^..<bad commit>` then redeploy, or roll back a single function in the
Cloud Console. Client: nothing is released yet, so just fix forward on `main`.

**Watch Crashlytics for a day.** The one change a real user could hit is `getPlay` returning
`permission-denied` for a play they are not in. No client flow does that — `getPlay` is only
reached from your own play lists — but that is the signal if the authorization policy is too
tight somewhere I did not anticipate.

### 2. Then, in rough value order

- **Backfill `totalCoopPlays`** if pre-existing co-op plays matter — a script over `plays`
  where `mode == "coop"`, incrementing `stats/{uid}.totalCoopPlays` for each entry in
  `participantIds`. Until then those users' Home PLAYS figures read low. Model it on the
  existing `functions/backfill-user-search.js`.
- **1.4 / D12 (campaign membership)** — the highest-value unfixed defect: two people cannot
  share one campaign board. `createPlay` never adds participants to `memberIds`, and the two
  creation paths disagree (`campaign_record_section.dart:76` passes `memberIds: const []`;
  `add_play_screen.dart:184` derives them from participants). Needs a product call on whether
  logging a session should imply joining the table.
- **1.14 / D-none (non-friend participants)** — also a product call: should the participant
  picker's global user search be friends-only? Today anyone can be added to a play and have
  their stats moved without consent.
- **D5 residual** — `EditPlayPage` can still exceed the player maximum; it holds only
  `gameId`/`gameName`, so fixing it means resolving the catalog game there.
- **Friend-request cards** carry the same stale-name snapshot D11 fixed for the friends list.
- **Accessibility** — icon-only controls (FAB, winner trophy, remove ×) expose no labels; this
  is the Part 8 VoiceOver item, and it is failing.
- **`updatePlay` has no `mode` guard.** Co-op plays hide Edit in the UI, so it is not reachable
  today, but D1 showed that "unreachable in the UI" is not a guarantee. Same bug class as D3.
- **Parts 2–8** of the manual test plan have still not been run.


---

# Handover — 2026-07-28 (session: P3 — Crashlytics + Analytics)

## Current Milestone

**Backlog P3: crash reporting + analytics.** Firebase Crashlytics for crash visibility
and Firebase Analytics for the three core funnels (`login`/`sign_up`, `add_play`,
`add_friend`). Plan file: `~/.claude/plans/for-the-crew-game-velvety-chipmunk.md`
(reused/overwritten — the name is stale). Plan was reviewed by a second agent before
implementation.

Status: **implemented; `flutter analyze` clean; `flutter test` 292 pass; `flutter build
apk --debug` succeeds.** NOT committed to main (on branch `feat/crashlytics-analytics`).
Device/Mac-only verification still outstanding (see Gravel).

## Context & Decisions (this session)

- **FlutterFire was already wired**, so this was incremental — no new Firebase project
  setup. `firebase_crashlytics ^4.3.10` + `firebase_analytics ^11.6.0` resolved cleanly
  against `firebase_core ^3.15.2` (via `flutter pub add`, not hand-pinned).
- **Crashlytics (`lib/main.dart`)**: platform-guarded to Android/iOS/macOS
  (`!kIsWeb && defaultTargetPlatform in {android,iOS,macOS}`); `FlutterError.onError`
  (chains the previous handler so the debug red-screen/console dump survives) +
  `PlatformDispatcher.instance.onError`; collection disabled when `kDebugMode ||
  _useEmulators`; `setUserIdentifier(uid)` via an `authStateChanges().listen`.
  `runZonedGuarded` deliberately omitted (redundant with `PlatformDispatcher.onError`).
- **Android native**: added `com.google.firebase.crashlytics` 3.0.2 to
  `android/settings.gradle.kts` + `android/app/build.gradle.kts`, and bumped
  `com.google.gms.google-services` 4.3.15 → 4.4.2 (recommended pairing). No minSdk/NDK
  change (minSdk already ≥23 via firebase_auth; Dart Crashlytics needs no NDK). Verified by
  a successful `flutter build apk --debug`. `android/gradle.properties` was auto-upgraded by
  that build (benign, kept).
- **Analytics (`lib/shared/services/analytics_service.dart`, new)**: thin wrapper with
  `enabled`/`disabled` factories; collection disabled in debug/emulator; the provider
  builds `FirebaseAnalytics.instance` **lazily inside the platform guard** so unsupported
  platforms and tests never touch it. Funnels wired at existing success points:
  `login_screen.dart` (converted to `ConsumerStatefulWidget`; logLogin/logSignUp for
  google + password), `add_play_screen.dart` `_save()` (logAddPlay with coop/competitive
  mode), `friends_screen.dart` `_sendRequest` (logAddFriend).
- **Screen-view auto-tracking deferred**: the app pushes unnamed `MaterialPageRoute`s, so
  `FirebaseAnalyticsObserver` would log null screen names — not worth it until routes are
  named.

## The 'Gravel' (non-obvious)

- **Test protection is NOT the platform guards** — in `flutter test`,
  `defaultTargetPlatform == TargetPlatform.android`, so guards evaluate *true*. Tests are
  safe only because (a) `main()` never runs and (b) `analyticsServiceProvider` is
  overridden with `const AnalyticsService.disabled()` (shared `test/helpers/analytics.dart`)
  wherever a screen could read it. `login_screen_test.dart` **had** to change: it pumped
  `const LoginScreen()` with no `ProviderScope`, which throws once LoginScreen is a Consumer.
- `PlatformDispatcher` resolved without an explicit `dart:ui` import (re-exported via
  widgets). If a future refactor drops that transitive path, add `import 'dart:ui'`.
- **Not verifiable on this Windows box** (still open): iOS `pod install` + build and the
  optional dSYM upload phase (Mac); a real device crash confirmed in the Crashlytics
  console; Analytics **DebugView** confirming the four events fire. The Android APK build
  is the only native verification done here.
- `macos/Flutter/GeneratedPluginRegistrant.swift` and `pubspec.lock` also carry pre-existing
  session-start edits; the macos registrant was left out of the P3 commit (generated file,
  regenerated on pub get).

## Next Immediate Step

Merge `feat/crashlytics-analytics` (the earlier Crew branch pattern), then do the device
pass: run on a real Android device, force a crash with collection enabled
(e.g. a temporary `FirebaseCrashlytics.instance.crash()` button), confirm it in the
Firebase console → Crashlytics for `gameshelf-283dc`, and confirm the analytics events in
Analytics DebugView.

---

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

## Post-merge ops (done this session)

- Merged to `main` (fast-forward `356173f → 87775ff`, bringing both this work and the
  28-calculators commit `6eeacc0`) and pushed; the `feat/crew-mission-tries` branch was
  deleted (local + remote).
- **Deployed Firestore rules + indexes to prod `gameshelf-283dc`**
  (`firebase deploy --only firestore:rules,firestore:indexes`): rules compiled/released,
  and the `campaigns` composite index (`memberIds` CONTAINS + `gameId`) is live — so
  `fetchCampaignsForGame` (the table picker) works in production now.
- **Ran `functions/migrate-crew-campaigns.js` against prod** (via gcloud ADC): **0 legacy
  Crew sheets found** — no `users/{uid}/campaigns` data existed, so it was a clean no-op.
  The script is idempotent; re-run if legacy data ever appears.

This closes the two long-standing "not deployed / not run" items from the 2026-07-24
co-op session (see its Gravel, now annotated).

## Next Immediate Step

On-device visual pass (still outstanding — no simulator on this box):
`firebase emulators:start` then `flutter run --dart-define=USE_EMULATORS=true`, log
The Crew → pick a table → verify the MISSION RECORD list, pinned CURRENT MISSION,
PASSED/FAILED, and the edit-mission dialog render/behave in light + dark.

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
- **Rules/index — DEPLOYED** (2026-07-28, see the top session's "Post-merge ops"). Was
  previously undeployed (`firebase deploy --only firestore:rules,firestore:indexes`).
- **Co-op edit is intentionally disabled** — `updatePlay` is still winner-centric; editing a co-op
  play would fail, so the edit button is hidden for them. Deferred.
- **Assumption baked in:** co-op plays are excluded from library `playCount` too (not just wins).
  They still appear in game-detail history via `fetchPlaysByGame`. Revisit if the user wants co-op
  plays counted in the "plays" totals.
- Legacy Crew data migration — **RUN** (2026-07-28): `functions/migrate-crew-campaigns.js`
  found **0 legacy sheets** in prod (clean no-op). Idempotent via a `migratedFrom` marker;
  re-run safely if legacy data ever appears.
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
