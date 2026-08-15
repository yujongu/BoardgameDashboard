/**
 * Input bounds for createPlay/updatePlay.
 *
 * Before these guards, `validate()` checked shape but never size. Every field
 * here is attacker-controlled and fans out into writes: each participant costs
 * ~5 writes across the play doc, its participants subcollection, stats,
 * gameStats and library, so an unbounded array turns one call into unbounded,
 * billable write amplification. Unbounded strings ride into Firestore up to the
 * 1 MB document ceiling.
 *
 * Participant *identity* is deliberately not checked: the participant picker
 * lets you add non-friends found by search, so any registered uid is a valid
 * participant by design.
 */

import { clearDb } from "./setup";
import {
  callCreatePlay,
  callUpdatePlay,
  type CreatePlayInput,
} from "./helpers/callables";
import {
  MAX_PARTICIPANTS,
  MAX_GAME_NAME_LENGTH,
  MAX_PLAYER_NAME_LENGTH,
  MAX_LOCATION_LENGTH,
  MAX_NOTES_LENGTH,
} from "../src/shared/auth";

const CHESS = { gameId: "chess", gameName: "Chess" };
const PLAYED_AT = "2024-01-15T10:00:00.000Z";
const CALLER = "u1";

/** A minimal valid play by CALLER alone. */
function soloPlay(overrides: Partial<CreatePlayInput> = {}): CreatePlayInput {
  return {
    ...CHESS,
    playedAt: PLAYED_AT,
    participants: [{ userId: CALLER, name: "Alice", isWinner: true }],
    ...overrides,
  };
}

/** [n] guest participants, the first of whom won. */
function guests(n: number): CreatePlayInput["participants"] {
  return Array.from({ length: n }, (_, i) => ({
    userId: null,
    name: `Guest ${i}`,
    isWinner: i === 0,
  }));
}

describe("play input bounds", () => {
  afterEach(clearDb);

  // ── Participant count ──────────────────────────────────────────────────────

  it(`rejects more than ${MAX_PARTICIPANTS} participants`, async () => {
    await expect(
      callCreatePlay(soloPlay({ participants: guests(MAX_PARTICIPANTS + 1) }), CALLER)
    ).rejects.toThrow(new RegExp(`at most ${MAX_PARTICIPANTS} participants`, "i"));
  });

  it(`accepts exactly ${MAX_PARTICIPANTS} participants`, async () => {
    const { playId } = await callCreatePlay(
      soloPlay({ participants: guests(MAX_PARTICIPANTS) }),
      CALLER
    );
    expect(typeof playId).toBe("string");
  });

  // ── Field lengths ──────────────────────────────────────────────────────────

  it("rejects an over-long gameName", async () => {
    await expect(
      callCreatePlay(
        soloPlay({ gameName: "x".repeat(MAX_GAME_NAME_LENGTH + 1) }),
        CALLER
      )
    ).rejects.toThrow(/gameName must be at most/i);
  });

  it("rejects an over-long participant name", async () => {
    await expect(
      callCreatePlay(
        soloPlay({
          participants: [
            {
              userId: CALLER,
              name: "x".repeat(MAX_PLAYER_NAME_LENGTH + 1),
              isWinner: true,
            },
          ],
        }),
        CALLER
      )
    ).rejects.toThrow(/Participant name must be at most/i);
  });

  it("rejects an over-long location", async () => {
    await expect(
      callCreatePlay(
        soloPlay({ location: "x".repeat(MAX_LOCATION_LENGTH + 1) }),
        CALLER
      )
    ).rejects.toThrow(/location must be at most/i);
  });

  it("rejects over-long notes", async () => {
    await expect(
      callCreatePlay(
        soloPlay({ notes: "x".repeat(MAX_NOTES_LENGTH + 1) }),
        CALLER
      )
    ).rejects.toThrow(/notes must be at most/i);
  });

  it("accepts every field exactly at its limit", async () => {
    const { playId } = await callCreatePlay(
      soloPlay({
        gameName: "x".repeat(MAX_GAME_NAME_LENGTH),
        location: "x".repeat(MAX_LOCATION_LENGTH),
        notes: "x".repeat(MAX_NOTES_LENGTH),
        participants: [
          {
            userId: CALLER,
            name: "x".repeat(MAX_PLAYER_NAME_LENGTH),
            isWinner: true,
          },
        ],
      }),
      CALLER
    );

    expect(typeof playId).toBe("string");
  });

  // ── updatePlay shares the same guards ──────────────────────────────────────

  it("enforces the notes cap on updatePlay", async () => {
    const { playId } = await callCreatePlay(soloPlay(), CALLER);

    await expect(
      callUpdatePlay(
        {
          playId,
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: [{ userId: CALLER, name: "Alice", isWinner: true }],
          notes: "x".repeat(MAX_NOTES_LENGTH + 1),
        },
        CALLER
      )
    ).rejects.toThrow(/notes must be at most/i);
  });

  it("enforces the participant cap on updatePlay", async () => {
    const { playId } = await callCreatePlay(soloPlay(), CALLER);

    await expect(
      callUpdatePlay(
        {
          playId,
          ...CHESS,
          playedAt: PLAYED_AT,
          participants: guests(MAX_PARTICIPANTS + 1),
        },
        CALLER
      )
    ).rejects.toThrow(new RegExp(`at most ${MAX_PARTICIPANTS} participants`, "i"));
  });
});
