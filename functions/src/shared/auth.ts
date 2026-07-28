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
