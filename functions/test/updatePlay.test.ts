/**
 * updatePlay tests.
 *
 * Test matrix:
 *  – Same game, winner changed
 *  – Same game, participant removed
 *  – Same game, participant added
 *  – Same game, counts unchanged but win swapped
 *  – Different game (full rollback + apply)
 *  – Duplicate userId in participants (aggregation)
 *  – User removed entirely from a play
 *  – Validation errors
 */

import {
  clearDb,
  getStats,
  getGameStats,
  getLibrary,
  getParticipants,
  getPlayDoc,
  playExists,
  db,
} from "./setup";
import {
  callCreatePlay,
  callUpdatePlay,
  type CreatePlayInput,
  type UpdatePlayInput,
} from "./helpers/callables";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const CHESS = { gameId: "chess", gameName: "Chess" };
const CATAN = { gameId: "catan", gameName: "Catan" };
const PLAYED_AT = "2024-01-15T10:00:00.000Z";
const PLAYED_AT_2 = "2024-01-16T10:00:00.000Z";

async function createChessPlay(
  participants: CreatePlayInput["participants"]
): Promise<string> {
  const { playId } = await callCreatePlay(
    { ...CHESS, playedAt: PLAYED_AT, participants },
    "u1"
  );
  return playId;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("updatePlay", () => {
  afterEach(clearDb);

  // ── Same game: winner changed ──────────────────────────────────────────────

  it("same game — flips totalWins when winner changes", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
      { userId: "u2", name: "Bob", isWinner: false },
    ]);

    // Swap winner: now Bob wins
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    // Stats: totalGamesPlayed unchanged, wins redistributed
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
    expect(await getStats("u2")).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });

    // GameStats: chess winCount updated
    expect(await getGameStats("u1", "chess")).toMatchObject({ playCount: 1, winCount: 0 });
    expect(await getGameStats("u2", "chess")).toMatchObject({ playCount: 1, winCount: 1 });

    // Library
    expect(await getLibrary("u1", "chess")).toMatchObject({ playCount: 1, winCount: 0 });
    expect(await getLibrary("u2", "chess")).toMatchObject({ playCount: 1, winCount: 1 });
  });

  // ── Location & notes ───────────────────────────────────────────────────────

  it("updates location and notes on the play document", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
        location: "Joey's place",
        notes: "close game",
      },
      "u1"
    );

    expect(await getPlayDoc(playId)).toMatchObject({
      location: "Joey's place",
      notes: "close game",
    });
  });

  it("clears location and notes when omitted from an update", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
        location: "Joey's place",
        notes: "close game",
      },
      "u1"
    );

    // Update without location/notes should remove the fields.
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    const doc = await getPlayDoc(playId);
    expect(doc?.location).toBeUndefined();
    expect(doc?.notes).toBeUndefined();
  });

  // ── Same game: participant removed ─────────────────────────────────────────

  it("same game — decrements stats for removed participant", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
      { userId: "u2", name: "Bob", isWinner: false },
      { userId: "u3", name: "Carol", isWinner: false },
    ]);

    // Remove Carol
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
        ],
      },
      "u1"
    );

    // Carol's stats roll back to zero
    expect(await getStats("u3")).toMatchObject({ totalGamesPlayed: 0, totalWins: 0 });

    // Carol's library entry deleted
    expect(await getLibrary("u3", "chess")).toBeNull();

    // u1 and u2 unchanged
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
    expect(await getStats("u2")).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
  });

  // ── Same game: participant added ───────────────────────────────────────────

  it("same game — increments stats for newly added participant", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    // Add Bob (loser)
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
        ],
      },
      "u1"
    );

    expect(await getStats("u2")).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
    expect(await getGameStats("u2", "chess")).toMatchObject({
      playCount: 1,
      winCount: 0,
    });
    expect(await getLibrary("u2", "chess")).toMatchObject({
      playCount: 1,
      winCount: 0,
    });

    // u1 unchanged
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
  });

  // ── Same game: no stat change ──────────────────────────────────────────────

  it("same game — no-op when participants and results are identical", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    // Re-submit the exact same data
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
    expect(await getGameStats("u1", "chess")).toMatchObject({ playCount: 1, winCount: 1 });
  });

  // ── Different game ─────────────────────────────────────────────────────────

  it("different game — rolls back old game and applies new game", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
      { userId: "u2", name: "Bob", isWinner: false },
    ]);

    // Change game from Chess to Catan
    await callUpdatePlay(
      {
        playId,
        ...CATAN,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
        ],
      },
      "u1"
    );

    // Old game (chess) stats rolled back
    expect(await getGameStats("u1", "chess")).toMatchObject({ playCount: 0, winCount: 0 });
    expect(await getGameStats("u2", "chess")).toMatchObject({ playCount: 0, winCount: 0 });
    expect(await getLibrary("u1", "chess")).toBeNull();
    expect(await getLibrary("u2", "chess")).toBeNull();

    // New game (catan) stats applied
    expect(await getGameStats("u1", "catan")).toMatchObject({ playCount: 1, winCount: 1 });
    expect(await getGameStats("u2", "catan")).toMatchObject({ playCount: 1, winCount: 0 });
    expect(await getLibrary("u1", "catan")).toMatchObject({ playCount: 1, winCount: 1 });
    expect(await getLibrary("u2", "catan")).toMatchObject({ playCount: 1, winCount: 0 });
  });

  it("different game — lifetime stats (totalGamesPlayed) unchanged when same players stay", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    await callUpdatePlay(
      {
        playId,
        ...CATAN,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    // Total played and wins don't change — just redistributed to another game
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
  });

  it("different game — totalWins changes when winner status changes across games", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    // Change game AND flip to loser
    await callUpdatePlay(
      {
        playId,
        ...CATAN,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
    expect(await getLibrary("u1", "catan")).toMatchObject({ playCount: 1, winCount: 0 });
  });

  // ── User removed entirely ──────────────────────────────────────────────────

  it("removes a user entirely — stats and library deleted", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
      { userId: "u2", name: "Bob", isWinner: false },
    ]);

    // Remove u2 entirely
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    expect(await getStats("u2")).toMatchObject({ totalGamesPlayed: 0, totalWins: 0 });
    expect(await getLibrary("u2", "chess")).toBeNull();
  });

  // ── Participants subcollection replaced ────────────────────────────────────

  it("replaces participants subcollection on update", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
      { userId: "u2", name: "Bob", isWinner: false },
    ]);

    // Update with a different set of participants
    await callUpdatePlay(
      {
        playId,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice Renamed", isWinner: false },
          { userId: "u3", name: "Carol", isWinner: true },
        ],
      },
      "u1"
    );

    const parts = await getParticipants(playId);
    expect(parts).toHaveLength(2);

    const names = parts.map((p) => p.name as string).sort();
    expect(names).toEqual(["Alice Renamed", "Carol"]);

    const carol = parts.find((p) => p.name === "Carol")!;
    expect(carol.isWinner).toBe(true);
  });

  it("updates play document fields (gameId, playedAt, participantIds)", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    await callUpdatePlay(
      {
        playId,
        ...CATAN,
        playedAt: PLAYED_AT_2,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
        ],
      },
      "u1"
    );

    const snap = await db.collection("plays").doc(playId).get();
    const data = snap.data()!;
    expect(data.gameId).toBe("catan");
    expect(data.gameName).toBe("Catan");
    expect(data.participantIds).toEqual(expect.arrayContaining(["u1", "u2"]));
    expect(data.participantCount).toBe(2);
  });

  // ── Multi-play context: update affects only this play's contribution ────────

  it("does not affect stats from OTHER plays when updating one play", async () => {
    // Play 1 (chess, u1 wins)
    const { playId: p1 } = await callCreatePlay(
      { ...CHESS, playedAt: PLAYED_AT, participants: [{ userId: "u1", name: "Alice", isWinner: true }] },
      "u1"
    );
    // Play 2 (chess, u1 loses)
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT_2,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    // Baseline: played=2, wins=1
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 2, totalWins: 1 });

    // Update play 1: Alice is now loser
    await callUpdatePlay(
      {
        playId: p1,
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    // Played still 2, wins drops to 0
    expect(await getStats("u1")).toMatchObject({ totalGamesPlayed: 2, totalWins: 0 });
    expect(await getGameStats("u1", "chess")).toMatchObject({ playCount: 2, winCount: 0 });
  });

  // ── Validation ─────────────────────────────────────────────────────────────

  // Regression for defects.md D4. This is the path the UI actually hit: the
  // Edit picker read the Add-Play state, so nobody showed as "Added" and the
  // same friend could be tapped a second time. Saving then gave that user
  // playCount 2 from a single play, and participantIds held their uid twice.
  it("throws invalid-argument when a registered user appears twice", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
        ],
      },
      "u1"
    );

    await expect(
      callUpdatePlay(
        {
          ...CHESS,
          playId,
          playedAt: PLAYED_AT,
          participants: [
            { userId: "u1", name: "Alice", isWinner: true },
            { userId: "u2", name: "Bob", isWinner: false },
            { userId: "u2", name: "Bob", isWinner: false },
          ],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });

    // The rejected edit must leave the original play untouched.
    expect(await getLibrary("u2", CHESS.gameId)).toMatchObject({
      playCount: 1,
    });
    const doc = await getPlayDoc(playId);
    expect(doc?.participantCount).toBe(2);
  });

  it("throws not-found when playId does not exist", async () => {
    await expect(
      callUpdatePlay(
        {
          playId: "nonexistent-play-id",
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "Alice", isWinner: true }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("throws invalid-argument when playId is empty", async () => {
    await expect(
      callUpdatePlay(
        {
          playId: "",
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "Alice", isWinner: true }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument when no winner", async () => {
    const playId = await createChessPlay([
      { userId: "u1", name: "Alice", isWinner: true },
    ]);

    await expect(
      callUpdatePlay(
        {
          playId,
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "Alice", isWinner: false }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});
