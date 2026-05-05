/**
 * Tests for read-only callable functions:
 *   – listMyPlays (pagination, cursor, user scope)
 *   – getPlay (full document + participants)
 *   – getMyLibrary (sorted list)
 *
 * Plays are seeded directly via the admin SDK (helpers/seed.ts) for precise
 * control over timestamps and document shapes.  Stats and library entries are
 * also seeded directly so these tests have no dependency on createPlay logic.
 */

import { clearDb, db } from "./setup";
import {
  callListMyPlays,
  callGetPlay,
  callGetMyLibrary,
  callGetMyLibraryNoAuth,
} from "./helpers/callables";
import {
  seedPlay,
  seedParticipant,
  seedLibrary,
} from "./helpers/seed";

// ─── listMyPlays ──────────────────────────────────────────────────────────────

describe("listMyPlays", () => {
  afterEach(clearDb);

  it("returns plays the authenticated user participated in", async () => {
    await seedPlay("play-a", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-03T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1", "u2"],
    });
    await seedPlay("play-b", {
      gameId: "catan", gameName: "Catan",
      playedAt: "2024-01-02T10:00:00.000Z",
      createdBy: "u2",
      participantIds: ["u2"],   // u1 NOT in this play
    });

    const result = await callListMyPlays({}, "u1");

    expect(result.plays).toHaveLength(1);
    expect(result.plays[0].playId).toBe("play-a");
    expect(result.plays[0].gameId).toBe("chess");
  });

  it("returns plays sorted by playedAt descending (newest first)", async () => {
    await seedPlay("play-old", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-01T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });
    await seedPlay("play-new", {
      gameId: "catan", gameName: "Catan",
      playedAt: "2024-01-03T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });
    await seedPlay("play-mid", {
      gameId: "wingspan", gameName: "Wingspan",
      playedAt: "2024-01-02T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });

    const result = await callListMyPlays({}, "u1");

    expect(result.plays.map((p) => p.playId)).toEqual([
      "play-new",
      "play-mid",
      "play-old",
    ]);
  });

  it("respects the limit parameter", async () => {
    for (let i = 1; i <= 5; i++) {
      await seedPlay(`play-${i}`, {
        gameId: "chess", gameName: "Chess",
        playedAt: `2024-01-0${i}T10:00:00.000Z`,
        createdBy: "u1",
        participantIds: ["u1"],
      });
    }

    const result = await callListMyPlays({ limit: 2 }, "u1");

    expect(result.plays).toHaveLength(2);
    expect(result.nextCursor).not.toBeNull();
  });

  it("returns nextCursor=null on the last page", async () => {
    await seedPlay("play-1", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-01T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });

    const result = await callListMyPlays({ limit: 10 }, "u1");

    expect(result.plays).toHaveLength(1);
    expect(result.nextCursor).toBeNull();
  });

  it("cursor pagination returns the correct next page", async () => {
    // 4 plays newest→oldest: play-4, play-3, play-2, play-1
    for (let i = 1; i <= 4; i++) {
      await seedPlay(`play-${i}`, {
        gameId: "chess", gameName: "Chess",
        playedAt: `2024-01-0${i}T10:00:00.000Z`,
        createdBy: "u1",
        participantIds: ["u1"],
      });
    }

    // Page 1: 2 most recent
    const page1 = await callListMyPlays({ limit: 2 }, "u1");
    expect(page1.plays.map((p) => p.playId)).toEqual(["play-4", "play-3"]);
    expect(page1.nextCursor).toBe("play-3");

    // Page 2: next 2
    const page2 = await callListMyPlays({ limit: 2, cursor: page1.nextCursor! }, "u1");
    expect(page2.plays.map((p) => p.playId)).toEqual(["play-2", "play-1"]);
    expect(page2.nextCursor).toBeNull();
  });

  it("cursor does not leak plays from other users", async () => {
    await seedPlay("play-u1", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-02T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });
    await seedPlay("play-u2", {
      gameId: "catan", gameName: "Catan",
      playedAt: "2024-01-01T10:00:00.000Z",
      createdBy: "u2",
      participantIds: ["u2"],
    });

    const result = await callListMyPlays({}, "u2");
    expect(result.plays.map((p) => p.playId)).toEqual(["play-u2"]);
  });

  it("maps PlaySummary fields correctly", async () => {
    await seedPlay("play-x", {
      gameId: "wingspan", gameName: "Wingspan",
      playedAt: "2024-03-15T14:30:00.000Z",
      createdBy: "u1",
      participantIds: ["u1", "u2", "u3"],
      participantCount: 3,
    });

    const result = await callListMyPlays({}, "u1");
    const summary = result.plays[0];

    expect(summary.playId).toBe("play-x");
    expect(summary.gameId).toBe("wingspan");
    expect(summary.gameName).toBe("Wingspan");
    expect(summary.participantCount).toBe(3);
    expect(new Date(summary.playedAt).toISOString()).toBe("2024-03-15T14:30:00.000Z");
  });

  it("returns empty array when user has no plays", async () => {
    const result = await callListMyPlays({}, "u-nobody");
    expect(result.plays).toHaveLength(0);
    expect(result.nextCursor).toBeNull();
  });
});

// ─── getPlay ──────────────────────────────────────────────────────────────────

describe("getPlay", () => {
  afterEach(clearDb);

  it("returns the play document with participants", async () => {
    await seedPlay("play-1", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-15T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1", "u2"],
    });
    await seedParticipant("play-1", { userId: "u1", name: "Alice", isWinner: true });
    await seedParticipant("play-1", { userId: "u2", name: "Bob", isWinner: false, score: 30 });

    const result = await callGetPlay("play-1", "u1");

    expect(result.playId).toBe("play-1");
    expect(result.gameId).toBe("chess");
    expect(result.gameName).toBe("Chess");
    expect(result.createdBy).toBe("u1");
    expect(result.participantCount).toBe(2);
    expect(result.participants).toHaveLength(2);

    const alice = result.participants.find((p) => p.name === "Alice")!;
    expect(alice.userId).toBe("u1");
    expect(alice.isWinner).toBe(true);

    const bob = result.participants.find((p) => p.name === "Bob")!;
    expect(bob.isWinner).toBe(false);
    expect((bob as { score?: number }).score).toBe(30);
  });

  it("includes guest participants (userId null)", async () => {
    await seedPlay("play-2", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-15T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });
    await seedParticipant("play-2", { userId: "u1", name: "Alice", isWinner: true });
    await seedParticipant("play-2", { userId: null, name: "Guest", isWinner: false });

    const result = await callGetPlay("play-2", "u1");

    expect(result.participants).toHaveLength(2);
    const guest = result.participants.find((p) => p.name === "Guest")!;
    expect(guest.userId).toBeNull();
  });

  it("returns playedAt as an ISO 8601 string", async () => {
    await seedPlay("play-3", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-06-21T08:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
    });
    await seedParticipant("play-3", { userId: "u1", name: "Alice", isWinner: true });

    const result = await callGetPlay("play-3", "u1");

    expect(() => new Date(result.playedAt)).not.toThrow();
    expect(new Date(result.playedAt).toISOString()).toBe("2024-06-21T08:00:00.000Z");
  });

  it("throws not-found when play does not exist", async () => {
    await expect(callGetPlay("does-not-exist", "u1")).rejects.toMatchObject({
      code: "not-found",
    });
  });

  it("includes optional fields (location, notes) when present", async () => {
    await seedPlay("play-4", {
      gameId: "chess", gameName: "Chess",
      playedAt: "2024-01-15T10:00:00.000Z",
      createdBy: "u1",
      participantIds: ["u1"],
      location: "Game Night Café",
      notes: "Best game ever.",
    });
    await seedParticipant("play-4", { userId: "u1", name: "Alice", isWinner: true });

    const result = await callGetPlay("play-4", "u1") as {
      location?: string;
      notes?: string;
      playId: string;
      gameId: string;
      gameName: string;
      playedAt: string;
      createdBy: string;
      participantCount: number;
      participants: unknown[];
    };

    expect(result.location).toBe("Game Night Café");
    expect(result.notes).toBe("Best game ever.");
  });
});

// ─── getMyLibrary ─────────────────────────────────────────────────────────────

describe("getMyLibrary", () => {
  afterEach(clearDb);

  it("returns all library entries for the authenticated user", async () => {
    await seedLibrary("u1", "chess", {
      gameName: "Chess", playCount: 5, winCount: 3,
      lastPlayedAt: new Date("2024-06-01T10:00:00Z"),
    });
    await seedLibrary("u1", "catan", {
      gameName: "Catan", playCount: 2, winCount: 0,
      lastPlayedAt: new Date("2024-05-01T10:00:00Z"),
    });

    const result = await callGetMyLibrary("u1");

    expect(result.library).toHaveLength(2);
    const ids = result.library.map((e) => e.gameId);
    expect(ids).toContain("chess");
    expect(ids).toContain("catan");
  });

  it("returns entries sorted by lastPlayedAt descending", async () => {
    await seedLibrary("u1", "chess", {
      gameName: "Chess", playCount: 1, winCount: 1,
      lastPlayedAt: new Date("2024-01-01T10:00:00Z"),
    });
    await seedLibrary("u1", "wingspan", {
      gameName: "Wingspan", playCount: 1, winCount: 0,
      lastPlayedAt: new Date("2024-03-01T10:00:00Z"),
    });
    await seedLibrary("u1", "catan", {
      gameName: "Catan", playCount: 1, winCount: 0,
      lastPlayedAt: new Date("2024-02-01T10:00:00Z"),
    });

    const result = await callGetMyLibrary("u1");

    expect(result.library.map((e) => e.gameId)).toEqual([
      "wingspan",
      "catan",
      "chess",
    ]);
  });

  it("maps entry fields correctly including lastPlayedAt as ISO string", async () => {
    await seedLibrary("u1", "chess", {
      gameName: "Chess", playCount: 7, winCount: 4,
      lastPlayedAt: new Date("2024-08-15T09:00:00Z"),
    });

    const result = await callGetMyLibrary("u1");
    const entry = result.library[0];

    expect(entry.gameId).toBe("chess");
    expect(entry.gameName).toBe("Chess");
    expect(entry.playCount).toBe(7);
    expect(entry.winCount).toBe(4);
    expect(new Date(entry.lastPlayedAt!).toISOString()).toBe("2024-08-15T09:00:00.000Z");
  });

  it("returns lastPlayedAt as null when absent", async () => {
    // Seed a library entry without lastPlayedAt by writing directly
    await db.collection("users").doc("u1").collection("library").doc("chess").set({
      gameId: "chess",
      gameName: "Chess",
      playCount: 1,
      winCount: 0,
      isOwned: false,
      // intentionally omit lastPlayedAt
    });

    const result = await callGetMyLibrary("u1");
    expect(result.library).toHaveLength(1);
    expect(result.library[0].lastPlayedAt).toBeNull();
  });

  it("returns empty array when user has no library entries", async () => {
    const result = await callGetMyLibrary("u-nobody");
    expect(result.library).toHaveLength(0);
  });

  it("throws unauthenticated when called without auth", async () => {
    await expect(callGetMyLibraryNoAuth()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("does not include other users' library entries", async () => {
    await seedLibrary("u1", "chess", {
      gameName: "Chess", playCount: 2, winCount: 1,
      lastPlayedAt: new Date("2024-01-01T10:00:00Z"),
    });
    await seedLibrary("u2", "catan", {
      gameName: "Catan", playCount: 3, winCount: 2,
      lastPlayedAt: new Date("2024-01-01T10:00:00Z"),
    });

    const result = await callGetMyLibrary("u1");

    expect(result.library.map((e) => e.gameId)).toEqual(["chess"]);
  });
});
