import {
  clearDb,
  db,
  getStats,
  getGameStats,
  getLibrary,
  getParticipants,
  getCampaign,
  seedCampaign,
} from "./setup";
import {
  callCreatePlay,
  callCreatePlayNoAuth,
  type CreatePlayInput,
} from "./helpers/callables";

// ─── Shared fixture ───────────────────────────────────────────────────────────

const CHESS: Pick<CreatePlayInput, "gameId" | "gameName"> = {
  gameId: "chess",
  gameName: "Chess",
};

const PLAYED_AT = "2024-01-15T10:00:00.000Z";

function oneWinner(uid: string, name: string): CreatePlayInput {
  return {
    ...CHESS,
    playedAt: PLAYED_AT,
    participants: [{ userId: uid, name, isWinner: true }],
  };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("createPlay", () => {
  afterEach(clearDb);

  // ── Happy-path: document creation ──────────────────────────────────────────

  it("returns a playId and persists the play document", async () => {
    const result = await callCreatePlay(oneWinner("u1", "Alice"), "u1");

    expect(typeof result.playId).toBe("string");
    expect(result.playId.length).toBeGreaterThan(0);

    const snap = await db.collection("plays").doc(result.playId).get();
    expect(snap.exists).toBe(true);
    expect(snap.data()).toMatchObject({
      gameId: "chess",
      gameName: "Chess",
      createdBy: "u1",
      participantCount: 1,
      participantIds: ["u1"],
    });
    // createdAt must be a Firestore Timestamp
    expect(snap.data()!.createdAt).toBeDefined();
  });

  it("creates participants in the subcollection", async () => {
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

    const parts = await getParticipants(playId);
    expect(parts).toHaveLength(2);
    const names = parts.map((p) => p.name as string).sort();
    expect(names).toEqual(["Alice", "Bob"]);

    const alice = parts.find((p) => p.name === "Alice")!;
    expect(alice.userId).toBe("u1");
    expect(alice.isWinner).toBe(true);

    const bob = parts.find((p) => p.name === "Bob")!;
    expect(bob.isWinner).toBe(false);
  });

  it("stores score on participant when provided", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [{ userId: "u1", name: "Alice", isWinner: true, score: 42 }],
      },
      "u1"
    );

    const [part] = await getParticipants(playId);
    expect(part.score).toBe(42);
  });

  // ── Stats ──────────────────────────────────────────────────────────────────

  it("increments totalGamesPlayed and totalWins for the winner", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");

    const stats = await getStats("u1");
    expect(stats).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
  });

  it("increments totalGamesPlayed but NOT totalWins for a loser", async () => {
    await callCreatePlay(
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

    const stats = await getStats("u2");
    expect(stats).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
  });

  it("accumulates stats across multiple plays", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    const stats = await getStats("u1");
    expect(stats).toMatchObject({ totalGamesPlayed: 2, totalWins: 1 });
  });

  // ── GameStats ──────────────────────────────────────────────────────────────

  it("creates gameStats with correct playCount and winCount", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");

    const gs = await getGameStats("u1", "chess");
    expect(gs).toMatchObject({
      gameId: "chess",
      gameName: "Chess",
      playCount: 1,
      winCount: 1,
    });
  });

  it("increments gameStats on repeated plays of the same game", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");
    await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    const gs = await getGameStats("u1", "chess");
    expect(gs).toMatchObject({ playCount: 2, winCount: 1 });
  });

  it("tracks gameStats independently per game", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");
    await callCreatePlay(
      {
        gameId: "catan",
        gameName: "Catan",
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );

    const chessGs = await getGameStats("u1", "chess");
    const catanGs = await getGameStats("u1", "catan");

    expect(chessGs).toMatchObject({ playCount: 1, winCount: 1 });
    expect(catanGs).toMatchObject({ playCount: 1, winCount: 0 });
  });

  // ── Library ────────────────────────────────────────────────────────────────

  it("creates a library entry on the first play", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");

    const lib = await getLibrary("u1", "chess");
    expect(lib).toMatchObject({
      gameId: "chess",
      gameName: "Chess",
      playCount: 1,
      winCount: 1,
      isOwned: false,
    });
    expect(lib!.firstPlayedAt).toBeDefined();
    expect(lib!.lastPlayedAt).toBeDefined();
  });

  it("does NOT overwrite firstPlayedAt on subsequent plays", async () => {
    await callCreatePlay(oneWinner("u1", "Alice"), "u1");
    const lib1 = await getLibrary("u1", "chess");
    const firstPlayedAt = lib1!.firstPlayedAt as { isEqual: (t: unknown) => boolean };

    await callCreatePlay(
      {
        ...CHESS,
        playedAt: "2024-02-01T10:00:00.000Z",
        participants: [
          { userId: "u1", name: "Alice", isWinner: false },
          { userId: "u2", name: "Bob", isWinner: true },
        ],
      },
      "u1"
    );
    const lib2 = await getLibrary("u1", "chess");

    expect(lib2).toMatchObject({ playCount: 2, winCount: 1 });
    expect(firstPlayedAt.isEqual(lib2!.firstPlayedAt)).toBe(true);
  });

  // ── Guest handling ─────────────────────────────────────────────────────────

  it("does not create stats or library for guest participants (userId null)", async () => {
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: null, name: "Guest Joe", isWinner: false },
        ],
      },
      "u1"
    );

    // Play document should reflect guest in participantCount but not participantIds
    const snap = await db.collection("plays").doc(playId).get();
    expect(snap.data()!.participantCount).toBe(2);
    expect(snap.data()!.participantIds).toEqual(["u1"]);

    // Guest Joe has no stats
    const guestStats = await db
      .collection("stats")
      .where("__name__", "!=", "u1")
      .get();
    expect(guestStats.empty).toBe(true);
  });

  // ── Multiple participants ──────────────────────────────────────────────────

  it("handles three registered participants with correct win attribution", async () => {
    await callCreatePlay(
      {
        gameId: "catan",
        gameName: "Catan",
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: "u2", name: "Bob", isWinner: false },
          { userId: "u3", name: "Carol", isWinner: false },
        ],
      },
      "u1"
    );

    const [s1, s2, s3] = await Promise.all([
      getStats("u1"),
      getStats("u2"),
      getStats("u3"),
    ]);

    expect(s1).toMatchObject({ totalGamesPlayed: 1, totalWins: 1 });
    expect(s2).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });
    expect(s3).toMatchObject({ totalGamesPlayed: 1, totalWins: 0 });

    const [l1, l2, l3] = await Promise.all([
      getLibrary("u1", "catan"),
      getLibrary("u2", "catan"),
      getLibrary("u3", "catan"),
    ]);

    expect(l1).toMatchObject({ playCount: 1, winCount: 1 });
    expect(l2).toMatchObject({ playCount: 1, winCount: 0 });
    expect(l3).toMatchObject({ playCount: 1, winCount: 0 });
  });

  // ── Validation errors ──────────────────────────────────────────────────────

  it("throws unauthenticated when called without auth", async () => {
    await expect(callCreatePlayNoAuth(oneWinner("u1", "Alice"))).rejects.toMatchObject(
      { code: "unauthenticated" }
    );
  });

  it("throws invalid-argument when gameId is empty", async () => {
    await expect(
      callCreatePlay(
        { gameId: "", gameName: "Chess", playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "Alice", isWinner: true }] },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument when no participants", async () => {
    await expect(
      callCreatePlay(
        { ...CHESS, playedAt: PLAYED_AT, participants: [] },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  // Regression for defects.md D4: a duplicated userId was counted once per row
  // by participantCount, participantIds, stats, gameStats and library, so one
  // play inflated that user's totals.
  it("throws invalid-argument when a registered user appears twice", async () => {
    await expect(
      callCreatePlay(
        {
          ...CHESS,
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
  });

  it("allows two guests to share a name", async () => {
    // Guests carry userId null, have no derived data, and may legitimately
    // repeat — the duplicate check must not catch them.
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: "u1", name: "Alice", isWinner: true },
          { userId: null, name: "Sam", isWinner: false },
          { userId: null, name: "Sam", isWinner: false },
        ],
      },
      "u1"
    );

    expect(await getParticipants(playId)).toHaveLength(3);
  });

  it("throws invalid-argument when no winner is set", async () => {
    await expect(
      callCreatePlay(
        {
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "Alice", isWinner: false }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument when playedAt is not a valid date", async () => {
    await expect(
      callCreatePlay(
        {
          ...CHESS,
          playedAt: "not-a-date",
          participants: [{ userId: "u1", name: "Alice", isWinner: true }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws invalid-argument when a participant has an empty name", async () => {
    await expect(
      callCreatePlay(
        {
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: "u1", name: "", isWinner: true }],
        },
        "u1"
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

// ─── Cooperative plays ──────────────────────────────────────────────────────────

describe("createPlay (cooperative)", () => {
  afterEach(clearDb);

  const CREW: Pick<CreatePlayInput, "gameId" | "gameName"> = {
    gameId: "the-crew-the-quest-for-planet-nine-2019",
    gameName: "The Crew",
  };

  function coopPlay(
    overrides: Partial<CreatePlayInput> = {}
  ): CreatePlayInput {
    return {
      ...CREW,
      playedAt: PLAYED_AT,
      participants: [
        { userId: "u1", name: "Alice", isWinner: false },
        { userId: "u2", name: "Bob", isWinner: false },
      ],
      mode: "coop",
      outcome: "win",
      ...overrides,
    };
  }

  async function seedCrewCampaign(id = "camp1"): Promise<string> {
    await seedCampaign(id, {
      gameId: CREW.gameId,
      gameName: CREW.gameName,
      memberIds: ["u1", "u2"],
      roster: ["Alice", "Bob"],
      stages: {},
    });
    return id;
  }

  it("persists a co-op play with mode + outcome and no winner", async () => {
    const { playId } = await callCreatePlay(coopPlay(), "u1");

    const snap = await db.collection("plays").doc(playId).get();
    expect(snap.data()).toMatchObject({ mode: "coop", outcome: "win" });

    const parts = await getParticipants(playId);
    expect(parts.every((p) => p.isWinner === false)).toBe(true);
  });

  it("records only the co-op counter — no gameStats, library, or win data", async () => {
    await callCreatePlay(coopPlay(), "u1");

    // gameStats and library stay untouched: co-op contributes no per-game
    // history and must not create a library entry for the game.
    expect(await getGameStats("u1", CREW.gameId)).toBeNull();
    expect(await getLibrary("u1", CREW.gameId)).toBeNull();

    // stats holds the co-op counter only. totalGamesPlayed and totalWins are
    // left absent so `totalGamesPlayed === sum(library.playCount)` still holds
    // and a co-op session never moves the win rate.
    const stats = await getStats("u1");
    expect(stats).toMatchObject({ totalCoopPlays: 1 });
    expect(stats?.totalGamesPlayed).toBeUndefined();
    expect(stats?.totalWins).toBeUndefined();
  });

  it("counts a co-op session for every registered participant", async () => {
    await callCreatePlay(coopPlay(), "u1");

    expect(await getStats("u1")).toMatchObject({ totalCoopPlays: 1 });
    expect(await getStats("u2")).toMatchObject({ totalCoopPlays: 1 });
  });

  it("advances the campaign stage on a win (completed latches true)", async () => {
    const id = await seedCrewCampaign();
    await callCreatePlay(coopPlay({ campaignId: id, stageId: "3" }), "u1");

    const camp = await getCampaign(id);
    const stages = camp!.stages as Record<string, Record<string, unknown>>;
    expect(stages["3"]).toMatchObject({
      completed: true,
      sessionCount: 1,
      lastOutcome: "win",
    });
  });

  it("records a loss without completing the stage, keeps session count", async () => {
    const id = await seedCrewCampaign();
    await callCreatePlay(
      coopPlay({ campaignId: id, stageId: "5", outcome: "loss" }),
      "u1"
    );

    const camp = await getCampaign(id);
    const stages = camp!.stages as Record<string, Record<string, unknown>>;
    expect(stages["5"]).toMatchObject({
      completed: false,
      sessionCount: 1,
      lastOutcome: "loss",
    });
  });

  it("does not downgrade a completed stage after a later loss", async () => {
    const id = await seedCrewCampaign();
    await callCreatePlay(coopPlay({ campaignId: id, stageId: "2" }), "u1");
    await callCreatePlay(
      coopPlay({ campaignId: id, stageId: "2", outcome: "loss" }),
      "u1"
    );

    const camp = await getCampaign(id);
    const stages = camp!.stages as Record<string, Record<string, unknown>>;
    expect(stages["2"]).toMatchObject({ completed: true, sessionCount: 2 });
  });

  it("advances the shared doc so a second member sees the progress", async () => {
    const id = await seedCrewCampaign();
    // u2 logs the session; the same shared doc is read back.
    await callCreatePlay(coopPlay({ campaignId: id, stageId: "1" }), "u2");

    const camp = await getCampaign(id);
    const stages = camp!.stages as Record<string, Record<string, unknown>>;
    expect(stages["1"].completed).toBe(true);
  });

  it("rejects a co-op play with no outcome", async () => {
    await expect(
      callCreatePlay(coopPlay({ outcome: undefined }), "u1")
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects campaignId without stageId", async () => {
    await expect(
      callCreatePlay(coopPlay({ campaignId: "camp1" }), "u1")
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a non-member advancing the campaign", async () => {
    const id = await seedCrewCampaign();
    await expect(
      callCreatePlay(coopPlay({ campaignId: id, stageId: "1" }), "intruder")
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects advancing a campaign that does not exist", async () => {
    await expect(
      callCreatePlay(coopPlay({ campaignId: "nope", stageId: "1" }), "u1")
    ).rejects.toMatchObject({ code: "not-found" });
  });
});
