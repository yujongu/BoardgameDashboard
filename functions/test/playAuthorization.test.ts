/**
 * Per-play authorization (defect D1 / manual-test-plan 1.13).
 *
 * Callables run with Admin SDK credentials that bypass firestore.rules, so each
 * one must re-apply the access check itself. Before the fix, `deletePlay`,
 * `updatePlay`, and `getPlay` verified only that the caller was signed in — any
 * authenticated user who supplied a playId got full read/write/delete on
 * someone else's play.
 *
 * Policy under test: any registered participant may read, edit, or delete.
 */

import { clearDb, getStats, getPlayDoc, playExists } from "./setup";
import {
  callCreatePlay,
  callDeletePlay,
  callGetPlay,
  callUpdatePlay,
  type CreatePlayInput,
} from "./helpers/callables";

const CHESS: Pick<CreatePlayInput, "gameId" | "gameName"> = {
  gameId: "chess",
  gameName: "Chess",
};
const PLAYED_AT = "2024-01-15T10:00:00.000Z";

const OWNER = "u1";      // creator and participant
const PARTICIPANT = "u2"; // participant, not creator
const STRANGER = "u3";    // neither

/** A play created by OWNER with PARTICIPANT alongside them. */
async function seedPlay(): Promise<string> {
  const { playId } = await callCreatePlay(
    {
      ...CHESS,
      playedAt: PLAYED_AT,
      participants: [
        { userId: OWNER, name: "Alice", isWinner: true },
        { userId: PARTICIPANT, name: "Bob", isWinner: false },
      ],
    },
    OWNER
  );
  return playId;
}

/** The edit payload used by the updatePlay cases. */
function editPayload(playId: string, notes: string) {
  return {
    ...CHESS,
    playId,
    playedAt: PLAYED_AT,
    participants: [
      { userId: OWNER, name: "Alice", isWinner: true },
      { userId: PARTICIPANT, name: "Bob", isWinner: false },
    ],
    notes,
  };
}

describe("per-play authorization", () => {
  afterEach(clearDb);

  // ── deletePlay ─────────────────────────────────────────────────────────────

  describe("deletePlay", () => {
    it("allows the creator to delete", async () => {
      const playId = await seedPlay();
      await callDeletePlay(playId, OWNER);
      expect(await playExists(playId)).toBe(false);
    });

    it("allows a non-creator participant to delete", async () => {
      const playId = await seedPlay();
      await callDeletePlay(playId, PARTICIPANT);
      expect(await playExists(playId)).toBe(false);
    });

    it("denies a non-participant", async () => {
      const playId = await seedPlay();
      await expect(callDeletePlay(playId, STRANGER)).rejects.toMatchObject({
        code: "permission-denied",
      });
    });

    it("leaves the play and its derived stats intact when denied", async () => {
      const playId = await seedPlay();
      const statsBefore = await getStats(OWNER);

      await expect(callDeletePlay(playId, STRANGER)).rejects.toMatchObject({
        code: "permission-denied",
      });

      // The guard throws inside the transaction, so nothing may be rolled back.
      expect(await playExists(playId)).toBe(true);
      expect(await getStats(OWNER)).toEqual(statsBefore);
    });

    it("stays idempotent for a play that does not exist", async () => {
      // The existence check precedes the guard, so a already-deleted play still
      // reports success rather than leaking whether that id ever existed.
      await expect(
        callDeletePlay("no-such-play", STRANGER)
      ).resolves.toMatchObject({ success: true });
    });
  });

  // ── updatePlay ─────────────────────────────────────────────────────────────

  describe("updatePlay", () => {
    it("allows the creator to edit", async () => {
      const playId = await seedPlay();
      await callUpdatePlay(editPayload(playId, "by owner"), OWNER);
      expect((await getPlayDoc(playId))?.notes).toBe("by owner");
    });

    it("allows a non-creator participant to edit", async () => {
      const playId = await seedPlay();
      await callUpdatePlay(editPayload(playId, "by participant"), PARTICIPANT);
      expect((await getPlayDoc(playId))?.notes).toBe("by participant");
    });

    it("denies a non-participant", async () => {
      const playId = await seedPlay();
      await expect(
        callUpdatePlay(editPayload(playId, "by stranger"), STRANGER)
      ).rejects.toMatchObject({ code: "permission-denied" });
    });

    it("does not mutate the play when denied", async () => {
      const playId = await seedPlay();
      const before = await getPlayDoc(playId);

      await expect(
        callUpdatePlay(editPayload(playId, "by stranger"), STRANGER)
      ).rejects.toMatchObject({ code: "permission-denied" });

      const after = await getPlayDoc(playId);
      expect(after?.notes).toBeUndefined();
      expect(after?.gameName).toBe(before?.gameName);
    });

    it("reports not-found before permission-denied for a missing play", async () => {
      // Ordering matters: a stranger probing ids should not be able to tell an
      // existing play from a missing one by the error code alone... but the
      // play must be loaded before participation can be checked at all.
      await expect(
        callUpdatePlay(editPayload("no-such-play", "x"), STRANGER)
      ).rejects.toMatchObject({ code: "not-found" });
    });
  });

  // ── getPlay ────────────────────────────────────────────────────────────────

  describe("getPlay", () => {
    it("allows the creator to read", async () => {
      const playId = await seedPlay();
      const result = await callGetPlay(playId, OWNER);
      expect(result.playId).toBe(playId);
    });

    it("allows a non-creator participant to read", async () => {
      const playId = await seedPlay();
      const result = await callGetPlay(playId, PARTICIPANT);
      expect(result.playId).toBe(playId);
    });

    it("denies a non-participant", async () => {
      // This is the read-side leak: location and notes are returned verbatim,
      // and firestore.rules explicitly forbids this for a direct client read.
      const playId = await seedPlay();
      await expect(callGetPlay(playId, STRANGER)).rejects.toMatchObject({
        code: "permission-denied",
      });
    });
  });

  // ── Guests ─────────────────────────────────────────────────────────────────

  it("denies everyone but the creator on an all-guest play", async () => {
    // Guests have userId === null, so they never enter participantIds and can
    // never authorize anyone.
    const { playId } = await callCreatePlay(
      {
        ...CHESS,
        playedAt: PLAYED_AT,
        participants: [
          { userId: OWNER, name: "Alice", isWinner: true },
          { userId: null, name: "Guest", isWinner: false },
        ],
      },
      OWNER
    );

    await expect(callGetPlay(playId, STRANGER)).rejects.toMatchObject({
      code: "permission-denied",
    });
    await expect(callDeletePlay(playId, STRANGER)).rejects.toMatchObject({
      code: "permission-denied",
    });
    await expect(callGetPlay(playId, OWNER)).resolves.toMatchObject({ playId });
  });
});
