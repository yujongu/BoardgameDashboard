import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";
import { UserLibraryDocument } from "../shared/types";

// ─── Input / output types ─────────────────────────────────────────────────────

interface GetMyLibraryData {}

interface LibraryEntry {
  gameId: string;
  gameName: string;
  playCount: number;
  winCount: number;
  lastPlayedAt: string | null;
}

interface GetMyLibraryResult {
  library: LibraryEntry[];
}

// ─── Safe field helpers ───────────────────────────────────────────────────────

function safeTimestampToISO(value: unknown, fieldName: string, docId: string): string | null {
  if (value == null) return null;
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string" && value.length > 0) {
    console.warn(`getMyLibrary: doc ${docId} field "${fieldName}" is a string, expected Timestamp — value: ${value}`);
    return value;
  }
  console.error(`getMyLibrary: doc ${docId} field "${fieldName}" is invalid:`, value);
  return null;
}

// ─── Callable function ────────────────────────────────────────────────────────

export const getMyLibrary = onCall<GetMyLibraryData>(async (request) => {
  console.log("getMyLibrary called");
  console.log("  auth uid :", request.auth?.uid ?? "(none)");

  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const userId = request.auth.uid;

    // No orderBy: Firestore excludes documents where the sorted field is absent.
    // Sorting in-memory ensures docs without lastPlayedAt are included (sorted last).
    console.log("Fetching library for user:", userId);
    const snap = await db
      .collection("users")
      .doc(userId)
      .collection("library")
      .get();

    console.log("Query result size:", snap.size);

    const library: LibraryEntry[] = snap.docs
      .map((doc) => {
        const entry = doc.data() as UserLibraryDocument;
        return {
          gameId: entry.gameId,
          gameName: entry.gameName,
          playCount: entry.playCount,
          winCount: entry.winCount,
          lastPlayedAt: safeTimestampToISO(entry.lastPlayedAt, "lastPlayedAt", doc.id),
        };
      })
      .sort((a, b) => {
        if (a.lastPlayedAt === null && b.lastPlayedAt === null) return 0;
        if (a.lastPlayedAt === null) return 1;
        if (b.lastPlayedAt === null) return -1;
        return b.lastPlayedAt < a.lastPlayedAt ? -1 : b.lastPlayedAt > a.lastPlayedAt ? 1 : 0;
      });

    console.log(`getMyLibrary OK — returning ${library.length} entries`);

    return { library } satisfies GetMyLibraryResult;

  } catch (error) {
    // Re-throw HttpsErrors as-is — they already have the right code and message.
    if (error instanceof HttpsError) throw error;

    // Unwrap any other error and surface the real message so Flutter sees it
    // instead of a generic INTERNAL.
    const message = error instanceof Error ? error.message : String(error);
    console.error("getMyLibrary UNHANDLED ERROR:", error);
    throw new HttpsError("internal", message);
  }
});
