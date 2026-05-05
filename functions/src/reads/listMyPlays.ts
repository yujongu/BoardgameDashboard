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

// ─── Safe field helpers ───────────────────────────────────────────────────────

function safeTimestampToISO(value: unknown, fieldName: string, docId: string): string {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  // Fallback: already an ISO string (e.g. written by a test helper)
  if (typeof value === "string" && value.length > 0) {
    console.warn(`listMyPlays: doc ${docId} field "${fieldName}" is a string, expected Timestamp — value: ${value}`);
    return value;
  }
  console.error(`listMyPlays: doc ${docId} field "${fieldName}" is invalid:`, value);
  throw new HttpsError("internal", `Document ${docId} has an invalid "${fieldName}" field (type: ${typeof value}).`);
}

// ─── Callable function ────────────────────────────────────────────────────────

export const listMyPlays = onCall<ListMyPlaysData>(async (request) => {
  console.log("listMyPlays called");
  console.log("  auth uid :", request.auth?.uid ?? "(none)");
  console.log("  input    :", JSON.stringify(request.data));

  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const data = request.data;
    validate(data);

    const userId = request.auth.uid;
    const { cursor } = data;
    const limitVal = Math.min(data.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

    // Build base query: plays the user participated in, newest first.
    // Requires composite index: participantIds (array-contains) + playedAt (desc).
    // Fetch one extra doc to detect whether another page exists.
    let query = db
      .collection("plays")
      .where("participantIds", "array-contains", userId)
      .orderBy("playedAt", "desc")
      .limit(limitVal + 1);

    if (cursor) {
      console.log("  cursor   :", cursor);
      const cursorSnap = await db.collection("plays").doc(cursor).get();
      if (!cursorSnap.exists) {
        throw new HttpsError(
          "not-found",
          `Cursor play ${cursor} no longer exists. Restart pagination from the first page.`
        );
      }
      query = query.startAfter(cursorSnap);
    }

    console.log(`Fetching plays for user: ${userId} (limit ${limitVal})`);
    const snap = await query.get();
    console.log("Query result size:", snap.size);

    const hasMore = snap.docs.length > limitVal;
    const pageDocs = hasMore ? snap.docs.slice(0, limitVal) : snap.docs;

    const plays: PlaySummary[] = pageDocs.map((doc) => {
      const play = doc.data() as PlayDocument;
      return {
        playId: doc.id,
        gameId: play.gameId,
        gameName: play.gameName,
        playedAt: safeTimestampToISO(play.playedAt, "playedAt", doc.id),
        participantCount: play.participantCount,
      };
    });

    const nextCursor = hasMore ? pageDocs[pageDocs.length - 1].id : null;
    console.log(`listMyPlays OK — returning ${plays.length} plays, hasMore: ${hasMore}`);

    return { plays, nextCursor } satisfies ListMyPlaysResult;

  } catch (error) {
    // Re-throw HttpsErrors as-is — they already have the right code and message.
    if (error instanceof HttpsError) throw error;

    // Unwrap any other error and surface the real message so Flutter sees it
    // instead of a generic INTERNAL.
    const message = error instanceof Error ? error.message : String(error);
    console.error("listMyPlays UNHANDLED ERROR:", error);
    throw new HttpsError("internal", message);
  }
});
