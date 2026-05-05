import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "../shared/db";
import { BoardGameDocument } from "../shared/types";

// ─── Constants ────────────────────────────────────────────────────────────────

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

// ─── Input / output types ─────────────────────────────────────────────────────

interface ListBoardGamesInput {
  /** Optional prefix to filter game names (case-sensitive). */
  search?: string;
  /** Number of results to return. Defaults to 20, max 100. */
  limit?: number;
}

interface BoardGameEntry {
  gameId: string;
  name: string;
}

interface ListBoardGamesResult {
  games: BoardGameEntry[];
}

// ─── Input validation ─────────────────────────────────────────────────────────

function validateInput(data: ListBoardGamesInput): {
  search: string | null;
  limit: number;
} {
  const { search, limit: rawLimit } = data;

  if (
    rawLimit !== undefined &&
    rawLimit !== null &&
    (!Number.isInteger(rawLimit) || rawLimit < 1 || rawLimit > MAX_LIMIT)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `limit must be an integer between 1 and ${MAX_LIMIT}.`
    );
  }

  if (search !== undefined && search !== null && typeof search !== "string") {
    throw new HttpsError("invalid-argument", "search must be a string.");
  }

  if (typeof search === "string" && search.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "search must be 100 characters or fewer."
    );
  }

  return {
    search: typeof search === "string" && search.trim().length > 0
      ? search.trim()
      : null,
    limit: rawLimit ?? DEFAULT_LIMIT,
  };
}

// ─── Callable function ────────────────────────────────────────────────────────

export const listBoardGames = onCall<ListBoardGamesInput>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { search, limit } = validateInput(request.data);

  let query = db
    .collection("boardGames")
    .orderBy("name")
    .limit(limit);

  if (search !== null) {
    // Firestore prefix match: name >= prefix AND name < prefix + high surrogate
    query = db
      .collection("boardGames")
      .orderBy("name")
      .where("name", ">=", search)
      .where("name", "<", search + "")
      .limit(limit);
  }

  const snap = await query.get();

  const games: BoardGameEntry[] = snap.docs.map((doc) => {
    const data = doc.data() as BoardGameDocument;
    return {
      gameId: doc.id,
      name: data.name,
    };
  });

  return { games } satisfies ListBoardGamesResult;
});
