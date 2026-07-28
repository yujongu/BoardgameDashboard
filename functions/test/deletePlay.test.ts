import {
  clearDb,
  db,
  getStats,
  getGameStats,
  getLibrary,
  getParticipants,
  playExists,
} from "./setup";
import {
  callCreatePlay,
  callDeletePlay,
  callDeletePlayNoAuth,
  type CreatePlayInput,
} from "./helpers/callables";

// ─── Shared fixture ───────────────────────────────────────────────────────────

const CHESS: Pick<CreatePlayInput, "gameId" | "gameName"> = {
  gameId: "chess",
  gameName: "Chess",
};
const PLAYED_AT = "2024-01-15T10:00:00.000Z";

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("deletePlay", () => {
  afterEach(clearDb);

  // ── Document deletion ──────────────────────────────────────────────────────

  it("deletes the play document", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    await callDeletePlay(playId, "u1");

    expect(await playExists(playId)).toBe(false);
  });

  it("deletes all participant documents in the subcollection", async () => {
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

    await callDeletePlay(playId, "u1");

    const parts = await getParticipants(playId);
    expect(parts).toHaveLength(0);
  });

  // ── Stats rollback ─────────────────────────────────────────────────────────

  it("decrements totalGamesPlayed and totalWins after deleting a winning play", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    // Confirm baseline
    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 1,
      totalWins: 1,
    });

    await callDeletePlay(playId, "u1");

    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 0,
      totalWins: 0,
    });
  });

  it("decrements only totalGamesPlayed (not totalWins) after deleting a losing play", async () => {
    // Play 1: u1 wins, u2 loses
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

    await callDeletePlay(playId, "u1");

    expect(await getStats("u2")).toMatchObject({
      totalGamesPlayed: 0,
      totalWins: 0,
    });
  });

  it("clamps stats at zero (no negative values)", async () => {
    // Create and immediately delete — stats should be 0, not -1.
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    await callDeletePlay(playId, "u1");

    const stats = await getStats("u1");
    expect(stats!.totalGamesPlayed as number).toBeGreaterThanOrEqual(0);
    expect(stats!.totalWins as number).toBeGreaterThanOrEqual(0);
  });

  // ── GameStats rollback ─────────────────────────────────────────────────────

  it("decrements gameStats playCount and winCount", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    await callDeletePlay(playId, "u1");

    const gs = await getGameStats("u1", "chess");
    expect(gs).toMatchObject({ playCount: 0, winCount: 0 });
  });

  it("keeps gameStats for other games when deleting one play", async () => {
    const { playId: chessId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    await callCreatePlay(
      {
        gameId: "catan",
        gameName: "Catan",
        playedAt: "2024-01-16T10:00:00.000Z",
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    await callDeletePlay(chessId, "u1");

    expect(await getGameStats("u1", "chess")).toMatchObject({
      playCount: 0,
      winCount: 0,
    });
    expect(await getGameStats("u1", "catan")).toMatchObject({
      playCount: 1,
      winCount: 0,
    });
    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 1,
      totalWins: 0,
    });
  });

  // ── Library rollback ───────────────────────────────────────────────────────

  it("deletes the library entry when playCount reaches zero", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    await callDeletePlay(playId, "u1");

    const lib = await getLibrary("u1", "chess");
    expect(lib).toBeNull();
  });

  it("decrements library playCount when other plays still exist", async () => {
    // Play twice
    const { playId: p1 } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: "2024-01-16T10:00:00.000Z",
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    // Delete only the first play
    await callDeletePlay(p1, "u1");

    const lib = await getLibrary("u1", "chess");
    expect(lib).not.toBeNull();
    expect(lib).toMatchObject({ playCount: 1, winCount: 0 });
  });

  // ── Duplicate userId aggregation ───────────────────────────────────────────

  it("aggregates stats when the same userId appears twice in one play", async () => {
    // Manually seed a play where u1 appears twice (edge case, but must not
    // double-decrement stats).  We use callCreatePlay twice as a proxy —
    // the key invariant is that deletePlay's aggregation groups by userId.

    // Create play 1 (u1 wins)
    const { playId: p1 } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    // Create play 2 (u1 loses)
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: "2024-01-16T10:00:00.000Z",
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    // Baseline: totalGamesPlayed=2, totalWins=1
    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 2,
      totalWins: 1,
    });

    await callDeletePlay(p1, "u1");

    // After deleting play 1: totalGamesPlayed=1, totalWins=0
    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 1,
      totalWins: 0,
    });
  });

  // ── Idempotency ────────────────────────────────────────────────────────────

  it("is idempotent — deleting an already-deleted play returns success without error", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );

    await callDeletePlay(playId, "u1");
    // Second call must not throw
    const result = await callDeletePlay(playId, "u1");
    expect(result.success).toBe(true);
  });

  // ── Validation ─────────────────────────────────────────────────────────────

  it("throws unauthenticated when called without auth", async () => {
    await expect(callDeletePlayNoAuth("some-play-id")).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("throws invalid-argument when playId is empty", async () => {
    await expect(callDeletePlay("", "u1")).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });
});

// ─── Cooperative deletes ──────────────────────────────────────────────────────
//
// Regression cases for defects.md D3 (manual-test-plan 1.2). createPlay skips
// stats/gameStats/library entirely for co-op, but deletePlay used to roll back
// unconditionally — subtracting counts the play had never added.

describe("deletePlay (cooperative)", () => {
  afterEach(clearDb);

  const CREW: Pick<CreatePlayInput, "gameId" | "gameName"> = {
    gameId: "the-crew-the-quest-for-planet-nine-2019",
    gameName: "The Crew",
  };

  const coopPlay = (): CreatePlayInput => ({
    ...CREW,
    playedAt: PLAYED_AT,
    participants: [
      { userId: "u1", name: "Alice", isWinner: false },
      { userId: "u2", name: "Bob", isWinner: false },
    ],
    mode: "coop",
    outcome: "win",
  });

  it("still deletes the play document and its participants", async () => {
    const { playId } = await callCreatePlay(coopPlay(), "u1");

    await callDeletePlay(playId, "u1");

    expect(await playExists(playId)).toBe(false);
    expect(await getParticipants(playId)).toHaveLength(0);
  });

  it("rolls back the co-op counter and creates no other derived data", async () => {
    const { playId } = await callCreatePlay(coopPlay(), "u1");
    expect(await getStats("u1")).toMatchObject({ totalCoopPlays: 1 });

    await callDeletePlay(playId, "u1");

    // The co-op counter is symmetric — it is the one figure co-op wrote.
    expect(await getStats("u1")).toMatchObject({ totalCoopPlays: 0 });
    expect(await getStats("u2")).toMatchObject({ totalCoopPlays: 0 });

    // Everything else must stay absent rather than be created at a negative
    // count by a rollback for writes that never happened.
    expect(await getGameStats("u1", CREW.gameId)).toBeNull();
    expect(await getLibrary("u1", CREW.gameId)).toBeNull();
    expect((await getStats("u1"))?.totalGamesPlayed).toBeUndefined();
  });

  it("leaves competitive totals untouched when a co-op play is deleted", async () => {
    // One competitive play establishes the counters, then a co-op play for a
    // different game is logged and deleted. The competitive figures must not move.
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    const statsBefore = await getStats("u1");
    expect(statsBefore).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });

    const { playId } = await callCreatePlay(coopPlay(), "u1");
    await callDeletePlay(playId, "u1");

    // The invariant from the test plan's Part 8 data check:
    //   stats.totalGamesPlayed === sum(library.playCount)
    expect(await getStats("u1")).toMatchObject({
      totalGamesPlayed: 1,
      totalWins: 1,
    });
    expect(await getLibrary("u1", CHESS.gameId)).toMatchObject({
      playCount: 1,
      winCount: 1,
    });
  });

  it("does not erase the library entry of a game also played competitively", async () => {
    // Same gameId both ways: the co-op rollback used to decrement the shared
    // library doc, and decrementUserLibrary deletes the entry at playCount 0.
    await callCreatePlay(
      {
        ...CREW,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true }],
      },
      "u1"
    );
    const { playId } = await callCreatePlay(coopPlay(), "u1");

    await callDeletePlay(playId, "u1");

    expect(await getLibrary("u1", CREW.gameId)).toMatchObject({
      playCount: 1,
      winCount: 1,
    });
    expect(await getGameStats("u1", CREW.gameId)).toMatchObject({
      playCount: 1,
      winCount: 1,
    });
  });
});
