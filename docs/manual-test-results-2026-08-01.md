# Manual Test Results — §1–§3, all 33 calculators — 2026-08-01

Run against `docs/single-account-test-guide.md` **§1–§3**.

- **Build:** `main` @ `b5cea6c`, debug, on an **iPhone 17 simulator (iOS 26.4)**.
- **Backend:** production (`gameshelf-283dc`), signed in as the owner's own account.
- **Driver:** taps and text via `idb`; **every result below was read off a device screenshot.**
- Home reads **"Recent Sessions"**, so this build includes `7e9c1c7` — the three "skip these"
  items at the top of the guide **do not** apply to this run.

Expected values were recomputed from the shipped formula in each
`lib/features/tools/<game>/<game>_calculator_screen.dart`, not copied from the guide.

**Result: 33/33 calculators arithmetically correct.** Four defects found, none of them in the
scoring maths — they are in catalog data, input commit, and error handling. New defects filed as
**D14–D17** in `docs/defects.md`.

---

## Summary

| Section | Scope | Result |
|---|---|---|
| §1 | 14 special-scoring calculators | **all pass** (1 defect found alongside: D16) |
| §2 | 19 additive calculators | **19/19 pass** (1 blocked entry path: D15) |
| §3 | common behaviour × 3 calculators | **pass**, except D17; 2 items not covered (below) |

### Not covered

- **Device rotation** (§3). `idb` has no rotate command and the Simulator's menu could not be
  driven — this box denies Accessibility permission to send keystrokes/menu clicks.
- **On-screen keypad questions** (§1.2, §3): whether the iOS keypad offers a minus sign, and
  whether the number pad has a Return key. The simulator ignored every attempt to disconnect the
  hardware keyboard (global pref, per-device pref via PlistBuddy, and the ⌘⇧K menu toggle), so
  the software keyboard never appeared. **All typing below went through a hardware keyboard.**
  This matters for D16 — see that entry. Both are a few seconds to check on a real device.

---

## §1 — Calculators with special scoring

### 1.1 Lost Cities — PASS

`total = (−20 + sum(numbers)) × (handshakes + 1)`, `+20 if numbers + handshakes ≥ 8`

| # | Handshakes | Cards | Expect | Got |
|---|---|---|---|---|
| a | 0 | 2–9 | 44 | **44** ✅ |
| b | 2 | 2–7 | 41 | **41** ✅ — **D6 confirmed fixed on device** (was 21) |
| c | 3 | 2–6 | 20 | **20** ✅ |
| d | 1 | 2–7 | 14 | **14** ✅ |
| e | 0 | 2 only | −18 | **−18** ✅ |
| f | 0 | none | 0 | **0** ✅ |

- ✅ Row (e) renders red on both the expedition score and the grand total; not clipped, no
  trailing-minus artifact.
- ✅ Expeditions keep independent state across swipes: Gold −18 and Blue −10 held separately,
  grand total −28.
- ✅ Reset clears all five columns and the grand total (verified by swiping back to Blue).

Note: this calculator is card-tap, not text entry — handshakes are three circles (tapping the
*n*th sets the count) and cards 2–10 toggle.

### 1.2 7 Wonders (classic) — PASS

- ✅ Science alone: tablets/compasses/gears 3/3/3 → **48**; header reads "SCIENCE (GREEN) — 48 VP".
- ✅ Coin rounding: 2 → **0**, 5 → **1**, 8 → **2**.
- ✅ Full player (military −2, coins 7, wonders 8, civilian 20, commercial 6, guilds 5,
  tablets 2, compasses 2, gears 1) → **55**, science 16 VP.
- ✅ Negative military accepted (`-2` parsed). Typed on a hardware keyboard — see "Not covered".
- ✅ Coin tiebreak: P1 civ 10 / 0 coins vs P2 civ 10 / 2 coins → both **10**, **"PLAYER 2 WINS"**.
  Per-player values retained when switching P1↔P2.

### 1.3 7 Wonders Duel — PASS

- ✅ Equal totals, different civilian → **"PLAYER 1 WINS (TIEBREAKER)"** (clearer than the guide
  anticipated — it names the tiebreak).
- ✅ Equal totals *and* equal civilian → **"TIE"**. The guide expected a `P1 · P2` label; on a
  fixed two-player screen "TIE" is unambiguous. **Guide wording, not a defect.**
- ✅ No military/scientific supremacy language anywhere — both appear as ordinary VP rows, so the
  screen does not imply instant wins are implemented.

### 1.4 Terraforming Mars — PASS on arithmetic, **1 defect (D16)**

- ✅ Fresh screen TR = **20**.
- ✅ TR 24, milestones 2, awards 5, greeneries 6, cities 9, card VP 12 → **66**.
- ✅ Clamping: 99 into Milestones (max 3) → **3** (+15 VP) and the "+" stepper disables at max.
- ✅ Card VP will not go negative: `-5` → **5** (digits-only formatter strips the sign); the "−"
  stepper is disabled at 0.
- ✅ Reset restores TR to 20 and all other rows to 0.
- ❌ **"typing a value then tapping away commits" does not hold** → **D16**.

### 1.5 Azul — PASS
- ✅ Placement 42, rows 3, columns 2, colours 1 → **72**.
- ✅ Multipliers not transposed: columns 1 alone → **7**; colours 1 alone → **10**.

### 1.6 Tigris & Euphrates — PASS
- ✅ 8/6/9/7 → **6**; black → 5 gives **5**; green → 0 gives **0**. Weakest colour, not the sum.
- ✅ The section header matches the totals bar in all three cases.
- ✅ Tied players share the win ("TIE: P1 · P2").
- Incidental: the app bar truncates "TIGRIS & EUPHRAT…" cleanly (a §7 item, passing early).

### 1.7 Photosynthesis — PASS
- ✅ P1 tokens 52 / light 3 vs P2 tokens 52 / light 7 → both totals **52**, **P2 wins**.
- ✅ Raising P1's light above P2's flips the winner to P1 with both totals still **52**.

### 1.8 Blokus — PASS
- ✅ All placed 1, monomino 1, remaining 0 → **20**.
- ✅ Nothing placed, 14 remaining → **−14** (negative legal; P2 at 0 wins).

### 1.9 Takenoko — PASS
- ✅ Panda 9, plots 7, gardener 11, emperor 2 → **31** (emperor doubled to 4).

### 1.10 Kingdomino — PASS
- ✅ Kingdom 47, Middle Kingdom 1, Harmony 1 → **62**.

### 1.11 Patchwork — PASS
- ✅ Buttons 18, 7×7 1, empty 6 → **13**.
- ✅ No player-count selector — only a P1/P2 "SHOWING" row, by design.

### 1.12 Point Salad — PASS
- ✅ 12, −5, 8, 0, 3, −2 → **16**; negatives accepted in every row.

### 1.13 Sushi Go / Sushi Go Party — PASS
- ✅ Sushi Go puddings −6 alone → total **−6**.
- ✅ Sushi Go Party desserts −4 alone → total **−4**.

---

## §2 — The additive 19 — 19/19 PASS

Each game got the guide's three checks: isolation (`1` in the first row → total 1), distinct
values, and clear (reset → 0). All 19 passed all three. Values 3, 5, 7, 11, 13, 17 across rows.

| Game | Expect | Got | | Game | Expect | Got |
|---|---|---|---|---|---|---|
| Wingspan | 56 | **56** ✅ | | Castles of Burgundy | 15 | **15** ✅ |
| Azul: Summer Pavilion | 1 | **1** ✅ | | Lords of Waterdeep | 15 | **15** ✅ |
| Cascadia | 15 | **15** ✅ | | Suburbia | 26 | **26** ✅ |
| Calico | 15 | **15** ✅ | | Scythe | 39 | **39** ✅ |
| Sagrada | 4 | **4** ✅ | | Lost Ruins of Arnak | 26 | **26** ✅ |
| Ticket to Ride | 111 | **111** ✅ | | Race for the Galaxy | 15 | **15** ✅ |
| Ticket to Ride: Europe | 163 | **163** ✅ | | Roll for the Galaxy | 15 | **15** ✅ |
| Parks | 15 | **15** ✅ | | Stone Age | 26 | **26** ✅ |
| Everdell | 26 | **26** ✅ | | Puerto Rico | 15 | **15** ✅ |
| Concordia | 56 | **56** ✅ | | | | |

**Guide correction:** §2 says the total should equal "the plain sum you compute yourself". That
is wrong by design for four of the nineteen, and the values above use the shipped formulas:

| Game | Shipped formula | Plain sum would say |
|---|---|---|
| Ticket to Ride | `routes + ticketsDone − ticketsFailed + longest × 10` | 26 (actual 111) |
| Ticket to Ride: Europe | `… + longest × 10 + stations × 4` | 39 (actual 163) |
| Sagrada | `public + private + favor − emptySpaces` | 26 (actual 4) |
| Azul: Summer Pavilion | `roundPlacement + starBonuses − leftover` | 15 (actual 1) |

Reaching Ticket to Ride: Europe at all required working around **D15**, since fixed.

---

## §3 — Behaviour common to all — on Wingspan, Azul, Patchwork

| Check | Result |
|---|---|
| Letters into a number field | ⚠️ **accepted into the field, scored as 0** → **D17**. No crash. |
| Leading zeros `007` | ✅ 7. Azul ×2 row → **14**; Patchwork ×7 row → **49** — multipliers still right |
| `999999` | ✅ total renders in full, no clipping, no negative overflow; chip shows `P1 · 999999` |
| Paste-length input (20 digits) | ✅ `int.tryParse` fails → total **0**, no crash, no overflow, row intact |
| Switch players back and forth | ✅ each player's values preserved (P1 33 / P5 42 held simultaneously) |
| Player count below selected player | ✅ 5 players → select P5 → drop to 2 → selection moves to **P2**, no stranding; regrowing to 5 restores P5's 42 |
| Identical totals → tie label | ✅ "TIE: P1 · P2" (and all five listed at 5 players) |
| Reset | ✅ every field and the totals bar clear, on all three |
| Background and return | ✅ HOME then relaunch → P1 33, P5 42, "PLAYER 5 WINS" all intact |
| Rotation | ⛔ not covered — see "Not covered" |

---

## Defects found — and their status

Filed in `docs/defects.md` as D14–D17. **All four are fixed and re-verified on the simulator.**

| | Defect | Status |
|---|---|---|
| **D16** — S2 | Terraforming Mars steppers do not commit a typed value when you tap away; the total silently under-reports while the number sits visible in the field | ✅ **fixed** — `onTapOutside` unfocuses, which routes through the existing `_commit()`. Re-ran the repro: 54 → **66** |
| **D15** — S3 | a duplicate `Ticket to Ride: Europe` catalog doc shadows the real one, making its calculator unreachable from Browse | ✅ **fixed 2026-08-02** — placeholder doc deleted with owner approval (it referenced nothing: 0 plays, 0 campaigns, 0 library entries). Browse now shows one row per game, with its calculator |
| **D14** — S3 | a failed catalog load shows "No games found" instead of the Retry error | ✅ **fixed** — dropped the `&& games == null` guard in both consumers; error now survives clearing the search box. Seen rendering "Could not load games" + RETRY |
| **D17** — S4 | score fields accept letters (no `inputFormatters`) and silently score them 0 | ✅ **fixed** — `digitsOnly`, plus a signed variant so the minus-bearing rows keep working |

After the fixes: `flutter analyze` clean, **`flutter test` 318 passing** (was 310 — 8 new
regression tests, each checked to fail when its fix is removed).
