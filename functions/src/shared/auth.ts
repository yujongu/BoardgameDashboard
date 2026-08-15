import { HttpsError } from "firebase-functions/v2/https";
import { PlayDocument } from "./types";

// ─── PER-PLAY AUTHORIZATION ──────────────────────────────────────────────────
//
// Callables run with Admin SDK credentials, which bypass firestore.rules by
// design (server code is trusted; rules cannot express multi-document business
// logic). `allow write: if false` on /plays is therefore only safe while every
// callable re-applies the access check the rules would have made for a direct
// client read.
//
// Checking `request.auth` alone answers "are you signed in?", never "may you
// touch THIS play?" — without the second question any authenticated caller who
// supplies a playId gets full read/write/delete on someone else's record.
//
// Policy: any registered participant may read, edit, or delete the play. This
// matches the read rule in firestore.rules:
//   allow read: if request.auth.uid in resource.data.participantIds;
// Guests carry userId === null, are absent from participantIds, and have no
// account to call with.
//
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Throws `permission-denied` unless [uid] is a registered participant of [play].
 *
 * Call this after the play document has been loaded and confirmed to exist, so
 * a missing play still surfaces as `not-found` rather than a permission error.
 */
export function assertParticipant(play: PlayDocument, uid: string): void {
  if (!play.participantIds.includes(uid)) {
    throw new HttpsError(
      "permission-denied",
      "You are not a participant of this play."
    );
  }
}

/**
 * Throws `invalid-argument` when a registered user appears more than once in
 * [participants].
 *
 * A duplicated userId is counted once per row by every write path — the play's
 * participantCount, its participantIds array, and that user's stats, gameStats
 * and library — so a single play inflates their totals by the number of rows.
 * deletePlay aggregates per unique userId when rolling back, so the inflation
 * is not even symmetrical: it survives deletion.
 *
 * Guests carry userId === null and are deliberately exempt — two guests may
 * share a name (or have none), and they have no derived data to double-count.
 */
export function assertNoDuplicateParticipants(
  participants: readonly { userId: string | null }[]
): void {
  const ids = participants
    .map((p) => p.userId)
    .filter((id): id is string => id !== null);

  if (new Set(ids).size !== ids.length) {
    throw new HttpsError(
      "invalid-argument",
      "A player may only appear once in a play."
    );
  }
}

// ─── INPUT BOUNDS ────────────────────────────────────────────────────────────
//
// Type-checking an input answers "is this the right shape?", never "is this a
// reasonable size?". Every field below is attacker-controlled and fans out into
// writes: each participant costs ~5 writes across the play doc, its participants
// subcollection, stats, gameStats and library, so an unbounded array turns one
// call into an unbounded, billable write amplification. Unbounded strings ride
// into Firestore up to the 1 MB document ceiling.
//
// ─────────────────────────────────────────────────────────────────────────────

/** Upper bound on players in a single play. Well above any real table. */
export const MAX_PARTICIPANTS = 20;

export const MAX_GAME_NAME_LENGTH = 100;
export const MAX_PLAYER_NAME_LENGTH = 50;
export const MAX_LOCATION_LENGTH = 100;
export const MAX_NOTES_LENGTH = 2000;

/**
 * Throws `invalid-argument` when [participants] exceeds [MAX_PARTICIPANTS].
 *
 * Sized off the Firestore transaction write budget rather than any game rule —
 * the cap exists to bound cost, not to model how many people can play.
 */
export function assertParticipantLimit(
  participants: readonly unknown[]
): void {
  if (participants.length > MAX_PARTICIPANTS) {
    throw new HttpsError(
      "invalid-argument",
      `A play may have at most ${MAX_PARTICIPANTS} participants.`
    );
  }
}

/**
 * Throws `invalid-argument` when any free-text field exceeds its cap.
 *
 * Applied to the fields a caller can set directly. Lengths are measured after
 * no trimming, so trailing whitespace counts against the budget exactly as it
 * would against the stored document.
 */
export function assertFieldLengths(data: {
  gameName: string;
  participants: readonly { name: string }[];
  location?: string;
  notes?: string;
}): void {
  const check = (value: string | undefined, max: number, label: string) => {
    if (value !== undefined && value.length > max) {
      throw new HttpsError(
        "invalid-argument",
        `${label} must be at most ${max} characters.`
      );
    }
  };

  check(data.gameName, MAX_GAME_NAME_LENGTH, "gameName");
  check(data.location, MAX_LOCATION_LENGTH, "location");
  check(data.notes, MAX_NOTES_LENGTH, "notes");
  for (const p of data.participants) {
    check(p.name, MAX_PLAYER_NAME_LENGTH, "Participant name");
  }
}
