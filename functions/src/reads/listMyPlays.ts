import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";
import { PlayDocument } from "../shared/types";

// ─── Input / output types ─────────────────────────────────────────────────────

interface ListMyPlaysData {
  limit?: number;
  /** playId of the last document returned by the previous page. */
  cursor?: string;
}

interface PlaySummary {
  playId: string;
  gameId: string;
  gameName: string;
  playedAt: string;
  participantCount: number;
}

interface ListMyPlaysResult {
  plays: PlaySummary[];
  /**
   * Pass this value as `cursor` on the next call to fetch the following page.
   * Null when this is the last page.
   */
  nextCursor: string | null;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: ListMyPlaysData): void {
  if (data.limit !== undefined && (!Number.isInteger(data.limit) || data.limit < 1)) {
    throw new HttpsError("invalid-argument", "limit must be a positive integer.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const listMyPlays = onCall<ListMyPlaysData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const userId = request.auth.uid;
  const { cursor } = data;
  const limitVal = Math.min(data.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

  // Build base query: plays the user participated in, newest first.
  // Fetch one extra doc to detect whether another page exists without a second query.
  let query = db
    .collection("plays")
    .where("participantIds", "array-contains", userId)
    .orderBy("playedAt", "desc")
    .limit(limitVal + 1);

  // Apply cursor: fetch the pivot document so startAfter works correctly
  // regardless of how many plays share the same playedAt timestamp.
  // Cost: 1 extra read per paginated page (zero cost on the first page).
  if (cursor) {
    const cursorSnap = await db.collection("plays").doc(cursor).get();
    if (!cursorSnap.exists) {
      throw new HttpsError(
        "not-found",
        `Cursor play ${cursor} no longer exists. Restart pagination from the first page.`
      );
    }
    query = query.startAfter(cursorSnap);
  }

  const snap = await query.get();
  const hasMore = snap.docs.length > limitVal;
  const pageDocs = hasMore ? snap.docs.slice(0, limitVal) : snap.docs;

  const plays: PlaySummary[] = pageDocs.map((doc) => {
    const play = doc.data() as PlayDocument;
    return {
      playId: doc.id,
      gameId: play.gameId,
      gameName: play.gameName,
      playedAt: (play.playedAt as Timestamp).toDate().toISOString(),
      participantCount: play.participantCount,
    };
  });

  const nextCursor = hasMore ? pageDocs[pageDocs.length - 1].id : null;

  return { plays, nextCursor } satisfies ListMyPlaysResult;
});
