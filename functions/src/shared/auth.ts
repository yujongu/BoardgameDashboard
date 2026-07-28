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
