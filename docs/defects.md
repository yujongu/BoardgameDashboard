# Gameshelf — Confirmed Defects (Part 1 execution, 2026-07-28)

Results of executing **Part 1** of `docs/manual-test-plan.md` against two iOS simulators
(iPhone 17 Pro + iPhone 17, iOS 26.5) and the Firebase Emulator Suite. Every entry below was
**reproduced**, not inferred — each carries the observed evidence.

Companion doc: `docs/backlog.md` (feature gaps). This file is runtime defects only.

Scoreboard: **14 confirmed** (1 fixed — D1), 1 not a defect (1.12), 1 not runnable here (1.16).
Severity key: **S1** data loss / security · **S2** wrong data · **S3** wrong UI · **S4** polish.

---

## S1 — Security & data loss

### D1 (plan 1.13). Any signed-in user can read, edit, or delete any play — **S1** — ✅ FIXED 2026-07-28

> **Fixed.** Policy chosen: **any registered participant** may read, edit, or delete.
> `assertParticipant` added in `functions/src/shared/auth.ts` and applied in `deletePlay`,
> `updatePlay`, and `getPlay`. Covered by `functions/test/playAuthorization.test.ts`
> (14 cases). Re-verified against the emulator: stranger → `403 PERMISSION_DENIED` on all
> three; non-creator participant → allowed. Details at the end of this entry.


- **What's wrong:** `deletePlay`, `updatePlay`, and `getPlay` verify that the caller is
  *authenticated*, but never that the caller is a participant or the creator of the play they
  name. Any signed-in user who supplies a `playId` gets full read/write/delete on it.
- **Repro / evidence:** account C (not a participant, not a friend, not the creator) called the
  emulated callables against an A+B play:
  ```
  updatePlay as C -> 200 {"result":{"success":true}}
  deletePlay as C -> 200 {"result":{"success":true}}
  play still exists after C deleted it? false
  getPlay   as C -> 200  (returned gameName, playedAt, createdBy, participants,
                          and would return location/notes when set)
  ```
- **Why the rules don't save you:** see the "Why Firestore rules don't cover this" section
  below — this is the single most misunderstood part of the bug.
- **Fix:** after loading the play doc, assert the caller is authorized before mutating:
  ```ts
  const play = playSnap.data() as PlayDocument;
  if (!play.participantIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "Not a participant of this play.");
  }
  ```
  Decide the policy first — **creator-only** (`play.createdBy === uid`) is stricter and matches
  "your play, your record"; **any-participant** matches the read rule already in
  `firestore.rules`. Whichever you pick, apply it identically in all three functions so the
  read rule and the callable agree. Note `deletePlay` returns early when the doc is missing
  (idempotency) — put the check *after* the existence check to preserve that.
- **As shipped:** `assertParticipant(play, uid)` in `functions/src/shared/auth.ts`, called in
  `deletePlay.ts`, `updatePlay.ts`, and `reads/getPlay.ts` immediately after the play doc is
  loaded and confirmed to exist — so a missing play still reports `not-found`, not
  `permission-denied`. `deletePlay` keeps its early return for an already-deleted play, so
  idempotency is preserved and probing a random id still just reports success.
- **Client impact: none.** Audited every caller. `getPlay` is reached only from Play Detail,
  which is opened from the user's own Home / Play History / Game Detail lists.
  `fetchSharedPlays` (friend profile) queries
  `plays.where('participantIds', arrayContains: uid)`, so it can only ever surface plays the
  caller is in. No legitimate flow relied on the old permissiveness.
- **Tests:** `functions/test/playAuthorization.test.ts` — 14 cases across the three functions
  (creator allowed, non-creator participant allowed, stranger denied, denied calls leave the
  play *and* its derived stats untouched, guests can't authorize anyone). Verified to be
  meaningful: with the guard neutered, exactly the 6 "denies" assertions fail and the 8
  positive-path ones still pass. Full suite: **146 passed**.

### D2 (plan 1.8). Delete failures are silent — **S1**

- **What's wrong:** the detail page pops the route *before* the Cloud Function resolves and
  calls `.ignore()` on the future, discarding errors. A failed delete is indistinguishable
  from a successful one.
- **Repro / evidence:** with the Functions emulator down (Firestore still up), Delete →
  confirm returned the user to Play History with **no error of any kind**; the play was still
  in Firestore afterwards (`plays: 3`, unchanged).
- **Fix:** await the call with a loading state, or keep the optimistic pop but surface a
  failure snackbar and re-insert the row. Pairs with backlog **H3** (same pattern on
  create/edit).
- **Files:** `lib/features/plays/play_detail_page.dart:113-117`.

---

## S2 — Wrong persisted data

### D3 (plan 1.2). Deleting a co-op play rolls back stats it never wrote — **S2**

- **What's wrong:** `createPlay` deliberately skips stats/gameStats/library for co-op
  (`if (coop || p.userId === null) continue;`), but `deletePlay` never reads `mode` and rolls
  everything back unconditionally.
- **Repro / evidence:**
  ```
  after 1 competitive play : totalGamesPlayed=1
  after 1 co-op play       : totalGamesPlayed=1   (correct — co-op writes nothing)
  after DELETING the co-op : totalGamesPlayed=0   (wrong — it never incremented)
    library/catan.playCount = 1   ->  stats says 0, library says 1
  ```
  A second sequence produced `totalWins`=2 with `totalGamesPlayed`=1 — an impossible state.
  This is exactly the Part 8 invariant (`stats.totalGamesPlayed == sum(library.playCount)`)
  breaking.
- **Fix:** read `mode` from the play doc and skip the derived-data rollback entirely when it
  is `"coop"`, mirroring `createPlay`. Guard against pre-existing corrupt counters at the same
  time (clamp at 0) — `decrementUserLibrary` deletes the library entry at playCount 0, so a
  spurious decrement can erase a game from a user's library outright.
- **Files:** `functions/src/plays/deletePlay.ts:56` (destructure `mode` alongside `gameId`),
  rollback loop at lines 106-112.

### D4 (plan 1.5). Edit Play can add a participant who is already in the play — **S2**

- **What's wrong:** the picker's "Added" marks come from the Add-Play provider, so when opened
  from **Edit** nobody is marked as already present. Adding the same friend twice is silently
  accepted, and the server does not dedupe on write.
- **Repro / evidence:** Add-Play picker shows `'B\nBob\nAdded'`; the **Edit** picker shows
  plain `'B\nBob'`. Tapping Bob a second time and saving produced:
  ```
  participantIds = ["uid-alice","uid-bob","uid-bob"]     participantCount: 6 -> 7
  Bob library.playCount = 2      Bob stats.totalGamesPlayed = 2      (from ONE play)
  ```
  Detail page renders two identical "Bob" rows.
- **Fix:** two layers. Client — seed the picker's "already added" set from the page being
  edited. Server — dedupe `participants` by `userId` in `updatePlay`/`createPlay` before
  writing (`deletePlay` already aggregates per unique userId, which is why the rollback is
  correct but the write is not). The server fix also limits the blast radius of D1.
- **Files:** `lib/features/plays/edit_play_page.dart`, the participant picker sheet,
  `functions/src/plays/updatePlay.ts`, `functions/src/plays/createPlay.ts:180-207`.

### D5 (plan 1.6). A play can exceed the game's maximum player count — **S2**

- **What's wrong:** `AddPlayState.canSave` checks `_effectiveMin` but never `_effectiveMax`,
  and switching games does not prune the existing participant list. `canAddParticipant` does
  respect the max, so the only route in is switching games after adding players.
- **Repro / evidence:** added 6 players to 7 Wonders (max 7), then switched the game to
  **7 Wonders Duel** (min 2, max 2). Counter read **"Players: 6 / 2"**, Save stayed enabled,
  and the play **saved**: `7 Wonders Duel  participantCount=6`. Home renders
  "7 Wonders Duel / 6 players".
- **Fix:** add `if (participants.length > _effectiveMax) return false;` to `canSave` and give
  the save bar a "TOO MANY PLAYERS" label; on game switch, either prune the overflow or block
  the switch with a warning.
- **Files:** `lib/features/plays/add_play_notifier.dart:73-86` (`canSave`), game-switch handler
  in the same notifier.

### D6 (plan 1.9). Lost Cities: wager cards don't count toward the 8-card bonus — **S2**

- **What's wrong:** `calculateExpeditionScore` tests `selectedNumbers.length >= 8`, but by the
  rulebook handshakes/wagers **are** cards and count toward the 8-card +20 bonus.
- **Repro / evidence:** in the calculator, 2 handshakes + number cards 2–7 (8 cards by the
  rules) scored **21**; correct is **41**. The loss is exactly 20 at every wager count,
  because the bonus is added after the multiplier:

  | wagers | numbers | app | correct |
  |---|---|---|---|
  | 0 | 8 | 44 | 44 ✓ |
  | 1 | 7 | 30 | 50 |
  | 2 | 6 | 21 | 41 |
  | 3 | 5 | 0  | 20 |

- **Fix:** `if (selectedNumbers.length + handshakeCount >= 8) total += 20;`
- **Files:** `lib/features/tools/lost_cities/expedition_column.dart:16`. Extend
  `test/features/tools/lost_cities/lost_cities_calculator_test.dart` with the boundary rows
  above.
- **Related:** the calculator tracks only one player's five expeditions — there is no
  second-player column for a 2-player game. Separate enhancement, not a defect.

### D7 (plan 1.15). Same-day plays sort by a phantom time — **S2**

- **What's wrong:** Add Play stores `DateTime.now()` unless the date picker is touched, in
  which case it stores **midnight local**. Two plays logged minutes apart on the same day can
  therefore sort in the wrong order.
- **Repro / evidence:** play 1 (date untouched) stored `2026-07-28T12:03:58Z`; play 2, logged
  *afterwards* with today tapped in the picker, stored `2026-07-27T15:00:00Z` (= 00:00 local,
  UTC+9). Play 2 sorts **below** play 1 in Recent Plays despite being newer. Both display
  "Jul 28".
- **Fix:** when the user picks a date, preserve the current time-of-day (or store the picked
  date at `now`'s clock time). Editing already preserves time-of-day, so this is Add Play only.
- **Files:** `lib/features/plays/add_play_screen.dart` (date-picker handler).

---

## S3 — Wrong or stale UI

### D8 (plan 1.1). Home PLAYS count disagrees with the Recent Plays list — **S3**

- **What's wrong:** the stat tile and the "Recent Plays" subtitle both sum
  `library.playCount`, which co-op plays never write; the list below streams *every* play.
- **Repro / evidence:** 2 competitive + 2 co-op plays →  tile **"PLAYS 2"**, subtitle
  **"2 PLAYS"**, **four cards listed**. Win rate also read **100%** while a logged co-op loss
  sat in the list, since co-op never enters the denominator.
- **Decision needed, not just a fix:** should co-op count toward plays, and toward win-rate's
  denominator? Options: (a) count co-op in plays but exclude from win rate, (b) exclude
  everywhere and label the list "Recent sessions", (c) show them as separate figures. (a) is
  the least surprising to a user looking at four cards under the number 2.
- **Files:** `lib/features/home/home_tab.dart`, the stats/library providers.

### D9 (plan 1.7). Play History keeps a play after you delete it — **S3**

- **What's wrong:** `PlayHistoryPage` holds its pages in local state and ignores the delete
  result, so the row survives. Home is correct because it streams.
- **Repro / evidence:** deleted one of four plays → history still listed **4 rows**
  (Firestore confirmed 3). Opening the dead row shows the cached header
  ("CATAN / July 28, 2026 / 3 PLAYERS") over **"Could not load players" + RETRY**, with the
  Edit button gone.
- **Fix:** use the boolean the detail route already pops back and remove the row (or refetch
  the page) on `true`.
- **Files:** `lib/features/plays/play_history_page.dart`.

### D10 (plan 1.11). Table picker sheet overflows with many tables — **S3**

- **What's wrong:** `_TablePickerSheet` is a non-scrollable `Column` inside a bottom sheet that
  is not `isScrollControlled`.
- **Repro / evidence:** with 10 Crew tables, Flutter rendered its overflow banner —
  **"BOTTOM OVERFLOWED BY 360 PIXELS"**. Only tables 10 → 4 were reachable; tables 3, 2, 1 and
  the **"New table" row** were unreachable, and the sheet does not scroll.
- **Fix:** wrap the children in a scrollable (`ListView`/`SingleChildScrollView`), pass
  `isScrollControlled: true`, and cap the sheet height (e.g. `DraggableScrollableSheet` or
  `maxHeight: 0.7 * screen`). Pin the "New table" row so it stays reachable.
- **Files:** `lib/features/plays/add_play_screen.dart:1379` (`_TablePickerSheet`) and the
  `showModalBottomSheet` call at line ~166.

### D11 (plan 1.10). Friends' names go stale after a rename — **S3**

- **What's wrong:** `users/{uid}/friends/{fid}` stores a **name snapshot** written at accept
  time and never refreshed.
- **Repro / evidence:** A renamed themself to "Alexandra"; `users/uid-alice.name` =
  `"Alexandra"` but `users/uid-bob/friends/uid-alice` still holds `{"name":"Alice"}`, and B's
  Friends tab renders "Alice". Persists indefinitely — it is stored data, not a cache, so no
  client refresh fixes it.
- **Fix:** either resolve names at read time in `getMyFriends` (join against `users/{uid}`),
  or fan out a name change to all `friends` docs on profile update (a Firestore trigger beside
  `syncUserSearch` is the natural home). Read-time resolution is simpler and always correct.
- **Files:** `functions/src/friends/getMyFriends.ts`, or a new trigger next to
  `functions/src/users/syncUserSearch.ts`. Check pending friend-request cards too.
- **Not a bug:** participant names on past plays are also snapshots — that is intended (a play
  record should preserve who played under the name they used).

---

## S3/S4 — Campaign model

### D12 (plan 1.4). No way to join someone else's campaign table — **S3**

- **What's wrong:** `memberIds` is only ever set at creation; `createPlay` never adds session
  participants to it, and tables are listed by `memberIds array-contains uid`. The two
  creation paths also disagree: Game Detail passes `memberIds: const []` (creator only), Add
  Play derives members from the participant list.
- **Repro / evidence:** A created a table and logged a session **with B as a participant**.
  Afterwards `memberIds` was still `["uid-alice"]`. B's Game Detail for the same game showed
  **"No campaigns yet"** while A saw 10 tables. Worse than the plan states — B is also hard
  blocked from logging to it:
  ```
  B logging to A's table -> 403 PERMISSION_DENIED "Only campaign members may log sessions."
  ```
  So one physical group cannot share one board; they end up with diverging boards.
- **Fix:** add registered participants to `memberIds` on co-op session write
  (`FieldValue.arrayUnion(...participantIds)`), and make the Game Detail "New table" path seed
  members the same way Add Play does. Consider an explicit invite/join affordance.
- **Files:** `functions/src/plays/createPlay.ts:209-227` (campaign write),
  `lib/features/library/campaign_record_section.dart:76`,
  `lib/shared/repositories/campaign_repository.dart:50-55`.

### D13 (plan 1.3). Deleting a co-op play does not rewind the campaign board — **S3**

- **What's wrong:** `createPlay` advances the stage (`completed`, `sessionCount++`);
  `deletePlay` has no campaign handling at all.
- **Repro / evidence:** logged a **won** mission 1, then deleted that play. Stages were
  unchanged afterwards: `{"1":{"completed":true,"sessionCount":1,"lastOutcome":"win"}}` — a
  completed mission with a recorded try, backed by a play that no longer exists.
- **Decision needed:** the stage "latching" may be intended (a mission you really did beat
  stays beaten). If so, document it and offer an explicit **undo** on the board card. If not,
  decrement `sessionCount` and recompute `completed` from the remaining plays on delete.
- **Files:** `functions/src/plays/deletePlay.ts` (no campaign branch exists yet).

---

## Not defects

### 1.12 — Stage stepper is impractical for Gloomhaven — **RESOLVED, strike from the plan**

Tapping the mission number opens a **"Mission"** dialog with a `1–50` range hint, so reaching
scenario 60 is a type, not 59 taps. Out-of-range input is handled: entering **999** clamped to
**50**. The Add-Play free stepper was already removed in an earlier session.

### 1.16 — Status bar hardcoded for dark — **appears already fixed, NOT verified**

`appBarTheme.systemOverlayStyle` switches `SystemUiOverlayStyle.light`/`.dark` by theme
(`lib/shared/theme/app_colors.dart:230`), and `ProfileAppBar` is a `SliverAppBar`, so the tab
screens inherit it. The `SystemChrome.setSystemUIOverlayStyle(...light)` call at
`lib/main.dart:79` is a harmless leftover that per-screen app-bar themes override.

**Caveat: not empirically tested.** This is an Android-only symptom and there is no Android
AVD on this machine (`flutter emulators` lists only the iOS simulator). Confirm on a real
Android device before closing.

---

## Found outside Part 1

- **Icon-only controls expose no accessibility labels.** The add-play FAB, the winner trophy,
  and the remove **×** all report `AXLabel = None` in the accessibility tree, as do the
  participant name/score fields. This is the Part 8 VoiceOver item failing; cheap to fix with
  `Semantics`/`tooltip` while D1 is being worked.
- **`getPlay` leaks plays to non-participants** — folded into **D1** above, but note the plan
  only listed `deletePlay`/`updatePlay`. The read side is affected too.
- **Field-name trap:** the callables read `users/{uid}.name`, not `displayName`. Seeding only
  `displayName` makes `sendFriendRequest` fail with
  `FAILED_PRECONDITION "Your profile is missing a name."` Worth aligning the two or
  documenting it.

---

## Why Firestore rules don't cover D1

`firestore.rules` **is** correct, and it is not the thing that failed:

```
match /plays/{playId} {
  allow read:  if request.auth != null
               && request.auth.uid in resource.data.participantIds;
  allow write: if false;
}
```

Rules govern **direct client access** to Firestore — a device talking to the database with a
user's ID token. Under them, C reading or writing an A+B play directly is denied.

But those rules are enforced by the *Firestore service* against *client* credentials. Cloud
Functions run on the server using the **Admin SDK**, which authenticates as a service account
and is designed to bypass security rules — server code is trusted, because rules are not
expressive enough for real business logic (transactions across many docs, aggregation, fan-out).
That bypass is not a flaw; the whole write path depends on it, which is why `allow write: if false`
is safe.

The consequence is that **a callable must re-implement the authorization the rules would have
applied**, because nothing else will. `deletePlay` implements only the first half:

```ts
if (!request.auth) throw new HttpsError("unauthenticated", ...);  // are you signed in?
// ...but never: are you allowed to touch THIS play?
```

So the chain is: client writes are closed → everything goes through callables → callables run
with rule-bypassing credentials → the callable checks only *authentication*, never
*authorization* → any signed-in user with a `playId` gets full access.

**C never holds Admin SDK credentials.** C is an ordinary user with an ordinary ID token. C
simply asks a trusted server function to act, and that function does not ask whether C is
entitled to what it is requesting — it acts with its own privileges on C's behalf. This is a
[confused deputy](https://en.wikipedia.org/wiki/Confused_deputy_problem): the deputy (the
function) is privileged, the caller is not, and the deputy fails to check.

The remaining barrier is only that C must know a `playId` — that is obscurity, not access
control. IDs leak through screenshots, shared links, logs, and support tickets, and are
guessable in bulk given enough attempts.
