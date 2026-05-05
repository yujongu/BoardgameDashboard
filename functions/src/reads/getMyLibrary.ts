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

// ─── Callable function ────────────────────────────────────────────────────────

export const getMyLibrary = onCall<GetMyLibraryData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  // No orderBy: Firestore excludes documents where the sorted field is absent.
  // Sorting in-memory ensures docs without lastPlayedAt are included (sorted last).
  const snap = await db
    .collection("users")
    .doc(request.auth.uid)
    .collection("library")
    .get();

  const library: LibraryEntry[] = snap.docs
    .map((doc) => {
      const entry = doc.data() as UserLibraryDocument;
      return {
        gameId: entry.gameId,
        gameName: entry.gameName,
        playCount: entry.playCount,
        winCount: entry.winCount,
        lastPlayedAt: entry.lastPlayedAt
          ? (entry.lastPlayedAt as Timestamp).toDate().toISOString()
          : null,
      };
    })
    .sort((a, b) => {
      if (a.lastPlayedAt === null && b.lastPlayedAt === null) return 0;
      if (a.lastPlayedAt === null) return 1;
      if (b.lastPlayedAt === null) return -1;
      return b.lastPlayedAt < a.lastPlayedAt ? -1 : b.lastPlayedAt > a.lastPlayedAt ? 1 : 0;
    });

  return { library } satisfies GetMyLibraryResult;
});
