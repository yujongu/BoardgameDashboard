# Single-Account Manual Test Guide

Step-by-step testing you can do **alone**, on the build already installed on your phone,
with no rebuild, no second account, and no emulator.

**Target build:** `main` @ `8cb94b3` (D12 merged). Written 2026-07-30.

## Before you start

- [ ] Confirm the build. Home's list header should read **"Recent Plays"**. If it reads
      **"Recent Sessions"** you are on a newer build and the three skips below no longer apply.
- [ ] This build points at **production**. Everything you log here is real data on your own
      account. Log against a game you don't mind polluting, and clean up at the end (§9).
- [ ] Have the Firestore console open for `gameshelf-283dc` — §8 is console-only.

### Skip these three — the fixes aren't in this build

| Item | Would show |
|---|---|
| Home PLAYS / list label (plan 1.1) | Old: PLAYS 4 with co-op counted, header "Recent Plays" |
| New-table sheet → add a **friend** → "Added" mark | Old: no feedback at all (the bug you found) |
| "Home PLAYS excludes co-op" (plan 4e) | Same change as 1.1 |

Everything else below is unaffected by the two uninstalled commits.

### How to record results

Tick the box if it matches. If it doesn't, write the line number and what you saw instead —
"expected 41, got 21" is worth ten times "calculator broken".

---

## 1. Calculators — special scoring

**Start here.** 28 of the 33 calculators were built in one session with only unit tests and
have never been checked by hand. Unit tests cannot catch a misread rulebook, because the test
encodes the same misreading — that is exactly how D6 (Lost Cities) survived.

Every expected total below was computed from the shipped formula, quoted with it.

Reach these via **Library → Browse all games → <game> → Score Calculator**.

### 1.1 Lost Cities

`total = (−20 + sum(numbers)) × (handshakes + 1)`, then `+20 if numbers + handshakes ≥ 8`

| # | Handshakes | Number cards | Expect |
|---|---|---|---|
| a | 0 | 2,3,4,5,6,7,8,9 | **44** |
| b | 2 | 2,3,4,5,6,7 | **41** ← this was 21 before D6 |
| c | 3 | 2,3,4,5,6 | **20** |
| d | 1 | 2,3,4,5,6,7 | **14** (7 cards — no bonus) |
| e | 0 | 2 only | **−18** |
| f | 0 | none | **0** |

- [ ] a–f all match.
- [ ] Row (e): the negative total renders in red, not clipped or as "-18-".
- [ ] Swipe between the five expeditions → each column keeps its own state.
- [ ] Reset → all five columns and the grand total clear.

### 1.2 7 Wonders (classic)

`science = t² + c² + g² + 7 × min(t,c,g)`
`total = military + (coins ÷ 3, rounded down) + wonders + civilian + commercial + guilds + science`

- [ ] Science alone: tablets 3, compasses 3, gears 3 → **48** (9+9+9+21).
- [ ] Coin rounding: coins 2 → adds **0**; coins 5 → **1**; coins 8 → **2**.
- [ ] Full player: military **−2**, coins 7, wonders 8, civilian 20, commercial 6, guilds 5,
      tablets 2, compasses 2, gears 1 → **55**.
- [ ] Negative military is accepted (the minus sign is reachable on the iOS number pad —
      note if it isn't; that's a real finding).
- [ ] Two players tie on total but differ on coins → the coin holder is declared winner.

### 1.3 7 Wonders Duel

- [ ] Equal totals, different civilian VP → civilian breaks the tie.
- [ ] Equal totals *and* equal civilian → true-tie label ("P1 · P2").
- [ ] Note: military/scientific supremacy instant wins are **not** implemented. Confirm the
      screen doesn't imply they are.

### 1.4 Terraforming Mars

`total = TR + milestones×5 + awardVp + greeneries + cityPoints + cardVp`

- [ ] Fresh screen: TR starts at **20**.
- [ ] TR 24, milestones 2, awards 5, greeneries 6, cities 9, card VP 12 → **66**.
- [ ] Steppers clamp at min/max; typing a value then tapping away commits and clamps it.
- [ ] Card VP will not go negative.

### 1.5 Azul

`total = placement + rows×2 + columns×7 + colors×10`

- [ ] Placement 42, rows 3, columns 2, colors 1 → **72**.
- [ ] Columns are ×7 and colors ×10 — a common place to transpose multipliers. Set rows 0,
      columns 1, colors 0, placement 0 → **7**, not 2 or 10.

### 1.6 Tigris & Euphrates

`total = min(red, blue, green, black)` — the *weakest* colour, not the sum

- [ ] Red 8, blue 6, green 9, black 7 → **6**.
- [ ] Change black to 5 → **5**.
- [ ] Set any one colour to 0 → **0**.
- [ ] The section header shows the same score as the totals bar.
- [ ] Tiebreak note: the real game compares next-weakest colour; this tool has tied players
      share the win. Confirm that's what you see.

### 1.7 Photosynthesis

`total = tokens only`; remaining **light is a winner tiebreak**, not points

- [ ] P1 tokens 52, light 3. P2 tokens 52, light 7 → both totals read **52**, and **P2** wins.
- [ ] Raising P1's light above P2's flips the winner without changing either total.

### 1.8 Blokus

`total = allPlaced×15 + monomino×5 − remaining`

- [ ] All pieces placed, monomino last, 0 remaining → **20**.
- [ ] Nothing placed, 14 squares remaining → **−14** (negative is legal here).

### 1.9 Takenoko

`total = panda + plots + gardener + emperor×2`

- [ ] Panda 9, plots 7, gardener 11, emperor 2 → **31** (emperor doubles: 4, not 2).

### 1.10 Kingdomino

`total = kingdom + middleKingdom×10 + harmony×5`

- [ ] Kingdom 47, Middle Kingdom 1, Harmony 1 → **62**.

### 1.11 Patchwork

`total = buttons + special7x7×7 − emptySpaces×2` — **2-player only, no player selector**

- [ ] Buttons 18, 7×7 tile 1, empty spaces 6 → **13**.
- [ ] Confirm there is genuinely no player-count selector (by design).

### 1.12 Point Salad

Six **signed** rows per player — scoring cards are random per game, so there's no category
breakdown by design.

- [ ] Enter 12, −5, 8, 0, 3, −2 → **16**.
- [ ] Negative entry is accepted in every row.

### 1.13 Sushi Go / Sushi Go Party

- [ ] The pudding (Sushi Go) / dessert (Party) row accepts a **negative** value and subtracts.
- [ ] Set only that row negative → the total goes below zero.

---

## 2. Calculators — the additive 19

The 14 games in §1 have multipliers, minimums or tiebreaks. The remaining **19** simply sum
their categories. Same recipe for each; ~2 minutes apiece.

Wingspan · Azul: Summer Pavilion · Cascadia · Calico · Sagrada · Ticket to Ride ·
Ticket to Ride Europe · Parks · Everdell · Stone Age · Puerto Rico · Concordia ·
Castles of Burgundy · Lords of Waterdeep · Suburbia · Scythe · Lost Ruins of Arnak ·
Race for the Galaxy · Roll for the Galaxy

For each:

- [ ] **Isolation:** enter `1` in the first category, leave the rest empty → total reads **1**.
      (Catches a category wired to the wrong field or silently multiplied.)
- [ ] **Sum:** enter distinct values across every category, e.g. 3, 5, 7, 11, 13, 17 → total
      equals the plain sum you compute yourself. Distinct values make a swapped pair visible.
- [ ] **Clear:** empty every field → total reads **0**, not blank or NaN.

Tick each game off here as you go (19):

- [ ] Wingspan
- [ ] Azul: Summer Pavilion
- [ ] Cascadia
- [ ] Calico
- [ ] Sagrada
- [ ] Ticket to Ride
- [ ] Ticket to Ride Europe
- [ ] Parks
- [ ] Everdell
- [ ] Stone Age
- [ ] Puerto Rico
- [ ] Concordia
- [ ] Castles of Burgundy
- [ ] Lords of Waterdeep
- [ ] Suburbia
- [ ] Scythe
- [ ] Lost Ruins of Arnak
- [ ] Race for the Galaxy
- [ ] Roll for the Galaxy

For a worked example, Wingspan is `birds + bonusCards + roundGoals + eggs + cachedFood +
tuckedCards`, so 24, 9, 6, 11, 4, 3 → **57**.

---

## 3. Calculators — behaviour common to all

Do this pass on **three** calculators of different shapes: Wingspan (plain), Azul
(multipliers), Patchwork (2-player, no selector).

- [ ] Type letters into a number field → rejected or ignored, no crash, total unchanged.
- [ ] Leading zeros (`007`) → treated as 7.
- [ ] Very large number (`999999`) → total doesn't overflow into a negative or clip the bar.
- [ ] Paste-style long input (hold-paste any long digit string) → handled.
- [ ] Switch players back and forth → each player's entered values are preserved.
- [ ] Reduce the player count below the currently selected player → selection doesn't strand
      on a player that no longer exists.
- [ ] Two players with identical totals → tie label appears (not an arbitrary winner).
- [ ] Rotate the device mid-entry → values survive.
- [ ] Reset → every field **and** the totals bar clear.
- [ ] Background the app and return → values still there.

---

## 4. Logging a competitive play

Add Play via the **+** FAB.

**Disabled-save states**

- [ ] No game selected → Save disabled.
- [ ] Game selected, no winner marked → Save disabled, and the label says why.
- [ ] Below the game's minimum players → Save reads **"NEED N PLAYERS"**.
- [ ] Add players past the maximum, then switch to a game with a lower cap (7 Wonders → 7
      Wonders Duel) → Save reads **"Remove N to fit M players"** and is inert. Participants
      are deliberately *not* auto-pruned.

**Participants**

- [ ] Your own row: name is read-only and has no remove ×.
- [ ] Add a guest by typing a name → saves; the guest gets no rank or stats.
- [ ] Add two guests with the **same** name → both allowed (guests are exempt from the
      duplicate rule).
- [ ] Remove a middle participant while its name field has focus, then edit the remaining
      names → confirm names and scores did **not** shift between rows. (This is the
      controller-index bug class; it's the one most likely to still be lurking.)

**Scores**

- [ ] `-5` → accepted. On iOS, note whether the number pad even offers a minus sign.
- [ ] `12.5` → accepted as a decimal.
- [ ] `1.2.3` → rejected or coerced sensibly, no crash.
- [ ] Score `0` vs left empty → check whether the detail page distinguishes them.
- [ ] A very long number → doesn't overflow the row.

**Fields and dates**

- [ ] Long location + multi-line notes → the detail page wraps them.
- [ ] Location and notes containing only spaces → stored as empty, not `" "`.
- [ ] Date picker: pick an old date → accepted. Try to reach a future date → unreachable.
- [ ] **Same-day ordering (D7):** log a play, wait a minute, log a second play and *tap
      today* in the date picker. The newer one must sort **above** the older on Home.

**Interaction edge cases**

- [ ] Open the keyboard on the last player row → the Save bar is still reachable and the
      focused field scrolls into view.
- [ ] Double-tap Save fast → exactly **one** play created (check Home).
- [ ] Double-tap the FAB → only one Add Play screen opens.
- [ ] Airplane mode → Save → error snackbar, the form is retained, nothing half-written.
- [ ] Background the app mid-save, return → sensible state, no duplicate.
- [ ] After a successful save, Home and Library refresh immediately.

---

## 5. Editing and deleting your own plays

- [ ] Open a play → Edit → change the notes → saves.
- [ ] Change the **score** → the detail page shows the new value.
- [ ] Change the **game** → the old game's library entry loses a play (and disappears if it
      hits 0); the new game's entry appears.
- [ ] Change the **date** → ordering updates on Home and in History, and the time-of-day is
      preserved.
- [ ] Edit → "+ Add player" → a participant already in the play shows **Added** and is not
      tappable (D4).
- [ ] Known gap, confirm don't report: Edit can still exceed the game's player maximum
      (D5 residual — `EditPlayPage` doesn't know the game's cap).
- [ ] Delete → **cancel** in the confirm dialog → nothing happens.
- [ ] Delete for real → the row disappears from Play History immediately (D9), and Home's
      counts drop.
- [ ] Delete the only play of a game → that game leaves both the Library and the Most Played
      leaderboard.
- [ ] Airplane mode → delete → **error snackbar and the play survives** (D2).
- [ ] iOS: edge swipe-back on Play Detail and Game Detail (both use `PopScope(canPop: false)`)
      → the gesture isn't dead-ended.

---

## 6. Co-op and campaign tables, solo

You can cover everything except the two-account sharing check.

**Creating a table**

- [ ] Add Play → The Crew → the **TABLE** picker leads; no winner trophies, no score fields,
      and no WON/LOST until a table is chosen.
- [ ] Table picker → **New table** → the sheet lists **you** as the first seat, under the hint
      that players can't be added or removed later.
- [ ] Your own seat has **no ×**.
- [ ] **+ Add player** → type a name that isn't a user → add as **guest** → transient "ADDED"
      flash, and the seat appears tagged **GUEST**. *(The friend-add "Added" mark is the
      skipped item — guests were never affected.)*
- [ ] Close the picker → the guest seat is on the list behind it.
- [ ] Remove a non-creator seat with × → it goes. This is the only moment seats can change.
- [ ] **Create table** → it's selected on the form and the mission controls appear.
- [ ] Open **New table** again and cancel (swipe/back) → no table created.
- [ ] Game Detail → the same New table flow works there and behaves identically.
- [ ] Pandemic (no board) → no table or mission controls at all, just RESULT WON/LOST.
- [ ] Create 8+ tables, then Add Play → Table → the list **scrolls** and "New table" stays
      reachable (D10).
- [ ] Table rows are labelled with their seats' names, comma-separated.

**Logging missions**

- [ ] Pick a table → the players list is **filled from the table and locked**: no
      "+ Add player", no remove ×, names not editable.
- [ ] **MISSION RECORD** list appears plus a pinned **CURRENT MISSION** with PASSED / FAILED.
- [ ] Save without PASSED/FAILED → disabled. Save without a table → disabled.
- [ ] Log **PASSED** → board advances; history row reads "Team won · Mission N"; reopening
      shows that mission completed with its tries and the current mission now N+1.
- [ ] Log **FAILED** → board does **not** advance; that mission's tries increments by 1;
      row reads "Team lost".
- [ ] Log PASSED on an already-completed mission → completion **latches** (stays complete).
- [ ] Tap a mission row → edit dialog → change **Tries**, toggle **Passed** → record updates
      and persists after reopening.
- [ ] Un-pass an earlier mission → it becomes the current mission again.
- [ ] After that edit, the players list is still the table's seats and still locked.
- [ ] Switch from The Crew to a competitive game mid-form → outcome/table/stage clear, winner
      UI returns, and the players list is **editable again**.
- [ ] Switch competitive → co-op *after* typing scores → scores are dropped; confirm nothing
      odd is stored.

**The board card on Game Detail**

- [ ] The crew list is **read-only**: plain chips, no ×, no **ADD** action.
- [ ] Stepper: step back from mission 5 to 3 → missions 3–5 become incomplete.
- [ ] Tap the big number → type `0`, `999`, and letters → clamped, no crash.
- [ ] **Correct Mission N** on a table past mission 1 → opens the edit dialog for the last
      completed stage (this is the deliberate D13 undo).

**Co-op elsewhere**

- [ ] Co-op play detail: result banner shown, **Edit hidden**, Delete present.
- [ ] Co-op games never appear in the **Library** tab — Browse all games is the discovery path.
- [ ] Delete a co-op play → the board does **not** rewind (by design; use Correct Mission).

---

## 7. Library, catalog, Game Detail

- [ ] Library sorted by most recently played; each win-rate bar matches its percentage.
- [ ] A game with 0 wins → **0%** and an empty bar, no divide-by-zero artifact.
- [ ] A very long game name → truncates cleanly on the card and in the app bar.
- [ ] Most Played: top **5** only, bar widths relative to the top game.
- [ ] Game Detail play count matches the number of history rows. For a **co-op** game, compare
      it with the Library card — Game Detail includes co-op, the Library card doesn't.
- [ ] Browse all games: type 1–3 characters (local search) then 4+ (remote merge) → no
      duplicate rows, no flicker to an empty state.
- [ ] Search a game outside the first 250 preloaded → found at 4+ characters.
- [ ] Type fast then clear the field → no stale results land afterwards.
- [ ] Airplane mode → catalog shows cached results or a clean Retry error.
- [ ] Open a game with no tools → "no tools" message.
- [ ] Open a game you've never played → empty history, tools/campaign card still work.

---

## 8. Cross-cutting

**Theme**

- [ ] Settings → System / Light / Dark → each applies immediately everywhere, **including any
      open dialog or bottom sheet**.
- [ ] Theme choice survives a full app restart.
- [ ] System mode: change the OS appearance while the app is foregrounded → it follows.
- [ ] Light-mode legibility on: the date picker, snackbars, the delete-confirm dialog,
      calculator accent colours, library card gradients.
- [ ] Note whether a game's library card colour changes between launches (the palette index
      comes from `gameId.hashCode` — if it shifts, that's a finding).

**Layout and accessibility**

- [ ] Largest system font size → player rows (fixed 50pt height), stat tiles, bottom nav
      labels, chips. Look for clipping.
- [ ] Landscape on the main tabs and on two calculators.
- [ ] **VoiceOver/TalkBack** over Home and Add Play → the icon-only controls (FAB, winner
      trophy, remove ×) are **expected to be unlabelled**. Confirm and note how bad it is;
      this is a known failure, not a discovery.
- [ ] Tap targets: winner trophy and remove × are small — judge them on the real device.

**Offline**

- [ ] Airplane mode on each screen: Home, Library, Game Detail, Friends, Play Detail, Add
      Play → each shows cached data or an error with Retry. **Never an infinite spinner.**
- [ ] Network back on → screens recover without a manual refresh.

**Lifecycle and navigation**

- [ ] Background/foreground on every screen, then force-quit and relaunch.
- [ ] Deep back-stack: Home → Play → Edit → game picker → back out repeatedly.
- [ ] Android hardware back from every screen, including bottom sheets and dialogs.
- [ ] Switch tabs while a load is in flight.
- [ ] Rotate mid-dialog.

**Profile**

- [ ] Change your name → Home greeting and Library header both update.
- [ ] Change your name to whitespace only → validation error.
- [ ] Name with emoji, RTL text, and 100 characters → check Profile, Friends rows, and
      participant chips for overflow.
- [ ] Forgot password with an empty/invalid email → prompt to enter one.
- [ ] Forgot password with an unregistered address → still reports "sent" (deliberate, no
      account enumeration).

---

## 9. Console check, then clean up

**Data integrity** — Firestore console, after all the above:

- [ ] `stats/{uid}.totalGamesPlayed` == sum of `users/{uid}/library/*.playCount`
      (competitive only). Divergence points at a duplicate participant or a bad rollback.
- [ ] `stats/{uid}.totalWins` == sum of `library.*.winCount`.
- [ ] No `library` doc left with `playCount: 0`.
- [ ] Every `plays` doc has a non-empty `participantIds` (an empty one is unreadable by
      anyone, forever).
- [ ] `campaigns` docs: `createdBy` appears in `memberIds`; `participants` is present on every
      doc you created; `stages` keys are within the game's stage count.
- [ ] After deleting a co-op play: `totalGamesPlayed` and every `library.playCount` unchanged,
      `totalCoopPlays` down by 1.

**Cleanup**

- [ ] Delete the plays you logged for testing.
- [ ] Delete the test tables you created (the board card allows deleting a table you're in).
- [ ] Re-check `stats/{uid}` reads sensibly afterwards — a botched rollback is easiest to spot
      the moment you've emptied everything.

---

## What this guide deliberately does not cover

Needs a second account: friend requests and the whole of Part 6, cross-user stats rollbacks,
and the D12 sharing round trip (Part 4b of the main plan).

Needs the emulator: every security probe (reading another user's docs, calling `deletePlay`
on a play you're not part of). Your build points at production, so those cannot be run here.

Needs a new build: the three skipped items at the top.
