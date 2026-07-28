# Gameshelf — Manual Test Plan

A checklist for hands-on testing. **Part 1** is targeted probes at places the code
suggests something is already wrong — do these first, they have the highest hit rate.
**Parts 2–8** are systematic coverage.

## Setup

- Two accounts (A and B) that are friends. A third, non-friend account (C) is useful.
- Two devices/simulators, or one device + the Firebase console, so you can watch
  shared state (campaigns, friendships) change from both sides.
- Keep the Firestore console open on `stats/{uid}`, `users/{uid}/library`, and
  `campaigns` — several bugs are only visible in the data, not in the UI.
- Test both **light and dark** themes, and both **iOS and Android**.
- For destructive experiments use the emulator suite (`firebase emulators:start` +
  `flutter run --dart-define=USE_EMULATORS=true`) rather than production.

---

## Part 1 — Suspected defects (targeted repros)

Each has the repro, what should happen, and what the code suggests will happen.

### 1.1 Home "PLAYS" count disagrees with the Recent Plays list (co-op)
Co-op plays deliberately skip all library/stats writes, but the Recent Plays stream
shows every play. The stat tile sums `library.playCount`; the list does not.

- [ ] Log 2 competitive plays, then log 2 co-op plays (The Crew or Pandemic).
- [ ] Home tab: stat tile says **PLAYS 2**, but four cards are listed and the
      "Recent Plays" header subtitle says "2 plays". Decide whether co-op should
      count toward plays (and toward win-rate's denominator).

### 1.2 Deleting a co-op play corrupts lifetime stats
`deletePlay` never checks `mode`, so it rolls back stats a co-op play never wrote.
`stats/{uid}.totalGamesPlayed` is decremented for a play that never incremented it.

- [ ] With A: log a few competitive plays (so `stats/{uid}` exists), note
      `totalGamesPlayed` in the console (or have B open A's friend profile).
- [ ] Log a co-op play, then delete it from its detail page.
- [ ] `stats/{uid}.totalGamesPlayed` drops by 1 (per registered participant) even
      though it never went up. B's view of A's profile now shows a too-low total.
- [ ] Repeat with a co-op play whose game A has *also* played competitively —
      `gameStats/{gameId}` and the library entry get decremented too, which can
      delete the library entry entirely (it deletes at playCount 0).

### 1.3 Deleting a co-op play does not rewind the campaign board
- [ ] Log a **won** Crew mission on a table → board advances to the next mission.
- [ ] Delete that play from its detail page.
- [ ] Board still shows the advanced mission and the stage's `sessionCount` is
      still incremented. Confirm this is intended (the stage "latches" by design)
      or needs an undo path.

### 1.4 No way to join someone else's campaign table
`memberIds` is only set at creation; `createPlay` never adds participants to it, and
tables are listed by `memberIds array-contains uid`.

- [ ] A creates a table from Game Detail → New table (roster empty, members = [A]).
- [ ] A logs a co-op session on that table with B as a participant.
- [ ] B opens the same game's detail page → **no tables listed**; B's own Add Play
      → Table shows nothing to pick, so B must create a second table for the same
      physical campaign. Two diverging boards for one group.
- [ ] Also check: if A creates the table from the Add Play flow instead, members
      come from the participant list — verify B *does* see it that way.

### 1.5 Edit Play lets you add a participant who is already in the play
The picker's "already added" marks come from the Add-Play provider, not from the
page being edited, so in Edit everyone except yourself looks un-added.

- [ ] Log a play with A + B. Open it → Edit → "+ Add player".
- [ ] B is **not** marked "Added". Tap B → two B rows in the play. Save.
- [ ] Check B's library/gameStats: one play counted **twice** (participantCount
      also becomes 3). Try it with both rows marked winner too.

### 1.6 A play can exceed the game's max players
`canSave` checks the minimum but never the maximum, and switching games doesn't
prune participants.

- [ ] Pick a 6-player game, add 6 players.
- [ ] Change the game to a 2-player game (e.g. 7 Wonders Duel).
- [ ] Counter reads "6 / 2" — check whether Save is still enabled and whether the
      play saves with 6 players in a 2-player game.

### 1.7 Play History keeps a play after you delete it
`PlayHistoryPage` holds its pages in local state and ignores the delete result.

- [ ] Log 3+ plays → Home → "See all" (Play History).
- [ ] Open a play → delete it → back.
- [ ] Row is still in the list. Tap it → participants fail to load. Home tab is
      correct (it streams), so only this screen is stale.

### 1.8 Delete failures are silent
The detail page pops *before* the Cloud Function resolves and `.ignore()`s the result.

- [ ] Turn on airplane mode → open a play → Delete → confirm.
- [ ] You are returned to the list with no error, as if it succeeded.
- [ ] Restore connectivity, pull the app back up: the play is still there.

### 1.9 Lost Cities: wager cards don't count toward the 8-card bonus
`calculateExpeditionScore` tests `selectedNumbers.length >= 8` only.

- [ ] Open Lost Cities calculator → one expedition → tap 2 handshakes + 6 number
      cards (8 cards total by the rulebook).
- [ ] No +20 bonus is applied. Confirm against the rules (wagers count as cards),
      then check the boundary at exactly 8 total cards with 0/1/2/3 wagers.
- [ ] Also worth checking: the calculator only tracks **one** player's five
      expeditions — there's no second-player column for a 2-player game.

### 1.10 Friends' names go stale after a rename
`users/{uid}/friends/{fid}` stores a name snapshot written at accept time.

- [ ] A and B are friends. A changes their name in Profile → Edit.
- [ ] B's Friends tab still shows A's **old** name (may persist indefinitely).
- [ ] Check the same for pending friend-request cards, and note that participant
      names on past plays are snapshots too (that one is probably intended).

### 1.11 Table picker sheet with many tables
`_TablePickerSheet` is a non-scrollable `Column` in a non-`isScrollControlled` sheet.

- [ ] Create 8–10 tables for The Crew (Game Detail → New table, repeatedly).
- [ ] Add Play → The Crew → Table. Look for a RenderFlex overflow / clipped list
      with no way to reach the lower entries or the "New table" row.

### 1.12 Stage stepper is impractical for Gloomhaven
Note: the free ± stepper was **removed from Add Play** — logging now pins to the current
(next-incomplete) stage. This entry now only applies to the **Game Detail board card**.
- [ ] Game Detail → Gloomhaven table → the board card stepper starts at 1 of 95 with
      ± buttons; you can also *tap the number to type* one. Confirm reaching scenario 60
      isn't 59 taps (typing works).

### 1.13 Any signed-in user can edit/delete any play (code-level)
`deletePlay` and `updatePlay` verify authentication but never verify that the caller
is a participant or the creator; Firestore rules don't apply (Admin SDK).

- [ ] Against the **emulator**, call `deletePlay` from account C with a `playId`
      belonging to A and B. Expect `permission-denied`; the code suggests success.
- [ ] Decide the intended policy (creator-only? any participant?) and add the check.

### 1.14 Non-friends can be added as participants
The participant picker surfaces a "Users" section from a global name search.

- [ ] From A, open Add Play → participants → search C (not a friend) → C is
      addable. Save.
- [ ] C's Home feed now shows a play they never agreed to, and their stats moved.
      Confirm whether this is intended or should be friends-only.

### 1.15 Same-day ordering looks wrong
Add Play stores `now` unless you touch the date picker, which sets midnight local.

- [ ] Log a play without touching the date (stores current time).
- [ ] Log a second play and tap today's date in the picker (stores 00:00).
- [ ] The second one sorts *below* the first in Recent Plays despite being newer.

### 1.16 Status bar style is hardcoded for dark
`main.dart` sets `statusBarIconBrightness: Brightness.light` once at startup.

- [ ] Android, light theme: check whether the status bar icons are white on a light
      background (invisible). Switch theme in Settings without restarting.

---

## Part 2 — Auth & profile

- [ ] Register with email/password → name prompt → lands on Home.
- [ ] Register with a password under 6 chars → inline error.
- [ ] Register with an email already in use → "email in use" error.
- [ ] Sign in with wrong password → generic incorrect-credentials error (no
      account enumeration).
- [ ] Forgot password with an empty/invalid email → prompt to enter one.
- [ ] Forgot password with an unregistered address → still says "sent" (by design).
- [ ] Sign in with Google, first time → users doc + userSearch doc created; verify
      you're findable in friend search immediately.
- [ ] Sign in with Google on an account with **no** display name → name prompt.
- [ ] Kill the app on the name-prompt screen and relaunch → prompt reappears.
- [ ] Go offline and complete the name prompt → error snackbar; verify you're not
      left as an authenticated user with no `users/{uid}` doc (this state blocks
      sending *and* receiving friend requests).
- [ ] Change your name in Profile → Home greeting and Library header update.
- [ ] Change your name to whitespace only → validation error.
- [ ] Name with emoji / RTL text / 100 characters → check layout on Profile,
      Friends rows, and participant chips.
- [ ] Sign out → sign in as a **different** account → Home, Library, and Friends
      show the new account's data (no leftovers from the previous session).
- [ ] Sign out while offline.

## Part 3 — Logging a play (competitive)

- [ ] Save with no game selected → button disabled.
- [ ] Save with no winner marked → button disabled; label explains why.
- [ ] Below min players → button reads "NEED N PLAYERS".
- [ ] Mark two winners → saves; both show a WINNER badge on the detail page.
- [ ] Add a guest (typed name, no account) → saves; guest has no rank/stats.
- [ ] Two guests with the same name.
- [ ] Add a friend, then try to add them again → shown as "Added", not tappable.
- [ ] Remove a middle participant while its name field has focus, then edit the
      remaining names → verify names/scores didn't shift between rows.
- [ ] Your own row: name is read-only and cannot be removed.
- [ ] Scores: negative (`-5`), decimal (`12.5`), `1.2.3`, empty, very long number.
      On iOS check whether the number pad even offers a minus sign.
- [ ] Score of `0` vs empty — does the detail page distinguish them?
- [ ] Long location and multi-line notes → detail page wraps them.
- [ ] Location/notes with only spaces → stored as empty, not " ".
- [ ] Date picker: pick an old date; confirm future dates are unreachable.
- [ ] Open the keyboard on the last player row → the Save bar is still reachable
      and the focused field scrolls into view.
- [ ] Double-tap Save quickly → only one play created.
- [ ] Double-tap the FAB → only one Add Play screen.
- [ ] Save while offline → error snackbar, form retained, nothing half-written.
- [ ] Background the app mid-save, return → sensible state.
- [ ] After saving, Home and Library refresh immediately.

## Part 4 — Logging a play (co-op / campaigns)

- [ ] Pick The Crew → winner trophies and score fields disappear; the **TABLE**
      picker leads (no WON/LOST yet — that only appears once a table is chosen).
- [ ] Pandemic (no board) → no table/mission controls; the plain RESULT WON/LOST
      alone is enough (one-shot co-op path is unchanged).
- [ ] Pick a table → a **MISSION RECORD** list appears (current mission first, then
      completed history each showing its tries) plus a pinned **CURRENT MISSION** =
      first incomplete mission with **PASSED / FAILED** buttons. There is **no free
      stage stepper** here anymore.
- [ ] Save without choosing PASSED/FAILED → disabled. Save without picking a table →
      disabled.
- [ ] Log PASSED on the current mission → board advances; history row reads
      "Team won · Mission N". Reopen the table → that mission shows as completed with
      its tries and the current mission is now N+1.
- [ ] Log FAILED on the current mission → board does **not** advance; the mission's
      tries (`sessionCount`) increments by 1; row reads "Team lost".
- [ ] Log PASSED on an already-completed mission → completion stays (latches).
- [ ] Tap a mission row in the record → edit dialog: change **Tries** and toggle
      **Passed**. Confirm the record updates, the change persists (reopen the table),
      and un-passing an earlier mission re-pins it as the current mission.
- [ ] Two members log the same mission at the same time from two devices → no lost
      update, `sessionCount` = 2.
- [ ] Member A edits the roster on the board while B has the page open → B's page
      is stale until reopened (no live listener). Confirm acceptable.
- [ ] Board stepper: step back from mission 5 to 3 → missions 3–5 are marked
      incomplete. Confirm that's intended (it discards completion, keeps history).
- [ ] Tap the big number → type a mission out of range (0, 999, letters).
- [ ] Add a roster member with a duplicate name → silently ignored.
- [ ] Switch from a co-op game to a competitive game mid-form → outcome/table/stage
      clear and the winner UI returns.
- [ ] Switch from competitive to co-op *after* typing scores → scores are dropped
      (server ignores them for co-op) — verify nothing surprising is stored.
- [ ] Co-op play detail: result banner shown, **Edit hidden**, Delete present.
- [ ] Co-op games never appear in the Library tab — confirm Browse-all is the
      intended discovery path.

## Part 5 — Editing & deleting plays

- [ ] Edit only the notes → save → detail updates; counts unchanged.
- [ ] Clear location and notes → fields disappear from the detail page.
- [ ] Change the winner → the old winner's win count decreases, the new one's
      increases (check both users' library entries).
- [ ] Change the **game** → the old game's library entry loses a play (and
      disappears entirely if it hits 0); the new game's entry appears.
- [ ] Change the date → check ordering in Home/History; the time-of-day is kept.
- [ ] Remove a participant → their library/stats roll back.
- [ ] Add a new participant → their library/stats appear.
- [ ] Edit a play created by someone else (you're a participant) → allowed? Decide.
- [ ] Delete a play you didn't create → check whether it's allowed and whether the
      other participants' stats roll back correctly.
- [ ] Delete the only play of a game → the game disappears from Library and from
      the Most Played leaderboard.
- [ ] Delete → cancel in the confirm dialog → nothing happens.
- [ ] Edit while offline.
- [ ] After editing from Game Detail, back out → the parent list refreshes.
- [ ] iOS: try the edge swipe-back gesture on Play Detail and Game Detail (both use
      `PopScope(canPop: false)`) — confirm the gesture isn't dead-ended.

## Part 6 — Friends

- [ ] Search by first-name prefix → found. Search by **surname** or a mid-word
      substring → not found (prefix-only search). Decide if that's acceptable.
- [ ] Search with different casing, leading/trailing spaces, an emoji name.
- [ ] Search yourself → excluded from results.
- [ ] Send a request → row flips to "Pending" immediately; appears in Outgoing.
- [ ] Send again from a different screen → "already exists" message.
- [ ] A sends to B while B sends to A (race) → the second is rejected cleanly.
- [ ] Accept → both sides see each other in Friends; the request disappears.
- [ ] Decline → sender's outgoing entry disappears (verify on the sender's device).
- [ ] Cancel an outgoing request → recipient's inbox clears.
- [ ] Accept a request twice (two devices) → idempotent, no duplicate friend rows.
- [ ] Inbox badge count matches the actual number of incoming requests, and clears
      after handling them.
- [ ] Remove a friend → both sides removed; re-sending a request afterwards works.
- [ ] After removal, open the (now ex-)friend's profile from an old route → the
      permission error is handled, not a raw crash.
- [ ] Friend profile: totals and top-5 games match what they see on their own Home.
- [ ] Friend with zero plays → empty states.
- [ ] Friend requests screen with 20+ entries → scrolls, times ("2 days ago") correct.
- [ ] Friends list while offline → cached data or a clean error with Retry.

## Part 7 — Library, Game Detail, catalog & tools

- [ ] Library empty state for a brand-new account.
- [ ] Library sorted by most recently played; win-rate bar matches the percentage.
- [ ] A game with 0 wins → 0% and an empty bar (no divide-by-zero artifacts).
- [ ] Very long game name → truncates without overflow on the card and in the app bar.
- [ ] Most Played leaderboard: top 5 only, bar widths relative to the top game.
- [ ] Game Detail play count matches the number of history rows (note: it includes
      co-op plays, unlike the Library card — compare them for a co-op game).
- [ ] Browse all games: type 1–3 chars (local search only) and 4+ chars (remote
      merge) → no duplicate rows, no flicker to empty.
- [ ] Search a game that isn't in the first 250 preloaded → found at 4+ chars.
- [ ] Type fast and clear the field → no stale results land afterwards.
- [ ] Catalog while offline → cached list or a Retry error.
- [ ] Open a game with no tools → "no tools" message.
- [ ] Each calculator: enter values, verify a hand-computed total.
  - [ ] **Lost Cities**: −20 base, ×(wagers+1), +20 at 8 cards (see 1.9); swipe
        between expeditions keeps each column's state; Reset clears all five.
  - [ ] **7 Wonders**: science = t²+c²+g²+7×sets; coins ÷ 3 rounded down; negative
        military accepted; ties broken by coins.
  - [ ] **7 Wonders Duel**: total tie → civilian VP tiebreaker → true tie label.
        Note there's no military/scientific-supremacy instant-win handling.
  - [ ] **Terraforming Mars**: TR starts at 20; steppers clamp at min/max; typing
        into the field and tapping away commits and clamps; no negative card VP.
  - [ ] **Wingspan**: switching player count keeps entered values; the winner label
        handles ties; reducing the player count doesn't strand the selected player.
- [ ] In every calculator: non-numeric input, leading zeros, huge numbers (999999),
      then rotate the device and check the values survive.
- [ ] Reset in each calculator clears everything, including the totals bar.

## Part 8 — Cross-cutting

**Offline / flaky network**
- [ ] Cold start with no network → splash → login or cached Home?
- [ ] Every screen with airplane mode on: Home, Library, Game Detail, Friends,
      Play Detail, Add Play. Each should show cached data or an error with Retry —
      never an infinite spinner.
- [ ] Turn the network back on → do the screens recover without a manual refresh?
- [ ] Slow network (Network Link Conditioner / emulator throttling) → check for
      double-submits and premature "empty" states.

**Theme & appearance**
- [ ] Settings → System / Light / Dark; each applies immediately everywhere,
      including open dialogs and bottom sheets.
- [ ] Theme choice survives an app restart.
- [ ] System mode: change the OS appearance while the app is foregrounded.
- [ ] Light mode legibility on: date-picker dialog, snackbars, the delete-confirm
      dialog, calculator accent colors, library card gradients.
- [ ] Note whether a game's library card color changes between app launches
      (the palette index comes from `gameId.hashCode`).

**Accessibility & layout**
- [ ] Largest system font size → player rows (fixed 50pt height), stat tiles,
      bottom nav labels, chips.
- [ ] Smallest device you support (iPhone SE) and a tablet.
- [ ] Landscape orientation on the main tabs and the calculators.
- [ ] VoiceOver/TalkBack pass over Home and Add Play — are the icon-only buttons
      (winner trophy, remove ×, FAB) announced meaningfully?
- [ ] Tap targets: the winner trophy and remove × are small — check on a real device.

**Lifecycle & navigation**
- [ ] Background/foreground on every screen; then force-quit and relaunch.
- [ ] Deep back-stack: Home → Play → Edit → game picker → back out repeatedly.
- [ ] Android hardware back from each screen, including bottom sheets and dialogs.
- [ ] Switch tabs while a load is in flight.
- [ ] Rotate mid-dialog.

**Data integrity spot check** (console, after a session of testing)
- [ ] `stats/{uid}.totalGamesPlayed` == sum of `users/{uid}/library/*.playCount`
      for competitive plays. Any divergence points at 1.2, 1.5, or a duplicate
      participant.
- [ ] `stats/{uid}.totalWins` == sum of `library.*.winCount`.
- [ ] No `library` doc with `playCount: 0`.
- [ ] Every `plays` doc has a non-empty `participantIds` (an empty one is
      unreadable by anyone, forever).
- [ ] `campaigns` docs: `createdBy` is in `memberIds`; `stages` keys are within
      the game's stage count.

**Security probes** (emulator only)
- [ ] Read another user's `plays` doc directly → denied.
- [ ] Read a non-friend's `stats` → denied.
- [ ] Write to `boardGames` → denied.
- [ ] Write another user's `userSearch` doc → denied.
- [ ] Call `createPlay` with a `participants` array containing a random uid →
      currently allowed; confirm that's the intended product behaviour (see 1.14).
- [ ] Call `deletePlay`/`updatePlay` on a play you're not part of (see 1.13).
