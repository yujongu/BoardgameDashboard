import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";
import {
  gameStatsRef,
  incrementGameStats,
  incrementStats,
  statsRef,
  upsertUserLibrary,
  userLibraryRef,
} from "../shared/helpers";

// ─── Input / output types ─────────────────────────────────────────────────────

interface ParticipantInput {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
}

interface CreatePlayData {
  gameId: string;
  gameName: string;
  /** ISO 8601 string — converted to Firestore Timestamp server-side. */
  playedAt: string;
  participants: ParticipantInput[];
  location?: string;
  notes?: string;
}

interface CreatePlayResult {
  playId: string;
}

/** Narrowed type used in Phase 1 and the write loop. */
type RegisteredParticipant = ParticipantInput & { userId: string };

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: CreatePlayData): void {
  if (!data.gameId?.trim()) {
    throw new HttpsError("invalid-argument", "gameId is required.");
  }
  if (!data.gameName?.trim()) {
    throw new HttpsError("invalid-argument", "gameName is required.");
  }
  if (!data.playedAt || isNaN(Date.parse(data.playedAt))) {
    throw new HttpsError(
      "invalid-argument",
      "playedAt must be a valid ISO 8601 date string."
    );
  }
  if (!Array.isArray(data.participants) || data.participants.length === 0) {
    throw new HttpsError("invalid-argument", "participants must not be empty.");
  }
  if (!data.participants.some((p) => p.isWinner)) {
    throw new HttpsError(
      "invalid-argument",
      "At least one participant must have isWinner = true."
    );
  }
  for (const p of data.participants) {
    if (!p.name?.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Every participant must have a non-empty name."
      );
    }
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const createPlay = onCall<CreatePlayData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const { gameId, gameName, participants, location, notes } = data;
  const createdBy = request.auth.uid;
  const playedAt = Timestamp.fromDate(new Date(data.playedAt));

  // Derive fields that are stable across transaction retries.
  const registered = participants.filter(
    (p): p is RegisteredParticipant => p.userId !== null
  );
  const participantIds = registered.map((p) => p.userId);

  // Allocate the ref outside the transaction so the ID is stable across retries.
  const playRef = db.collection("plays").doc();

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ — userLibrary only ─────────────────────────────────────
    //
    // stats/{userId} and stats/{userId}/gameStats/{gameId} are intentionally
    // absent. FieldValue.increment + set/merge handles create-or-increment
    // atomically — no prior read is needed.
    //
    // users/{userId}/library/{gameId} requires a snapshot to detect the first
    // play per user and set firstPlayedAt. Firestore merge has no
    // "set field only if absent" primitive, so existence must be checked here.

    const libRefs = registered.map((p) => userLibraryRef(p.userId, gameId));
    const libSnaps = libRefs.length > 0 ? await tx.getAll(...libRefs) : [];

    // Index by userId for O(1) lookup inside the write loop.
    const libSnapByUserId = new Map(
      registered.map((p, i) => [p.userId, libSnaps[i]])
    );

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    // 1. Play document.
    tx.set(playRef, {
      gameId,
      gameName,
      playedAt,
      createdBy,
      participantCount: participants.length,
      participantIds,
      ...(location && { location }),
      ...(notes && { notes }),
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Participants subcollection + derived stats per registered user.
    for (const p of participants) {
      // 2a. Participant document.
      tx.set(playRef.collection("participants").doc(), {
        userId: p.userId,
        name: p.name,
        isWinner: p.isWinner,
        ...(p.score !== undefined && { score: p.score }),
        joinedAt: FieldValue.serverTimestamp(),
      });

      // Guests (userId === null) have no stats or library entries to update.
      if (p.userId === null) continue;

      // 2b. Lifetime stats — write-only, FieldValue.increment creates on first call.
      incrementStats(tx, statsRef(p.userId), p.isWinner, playedAt);

      // 2c. Per-game stats — write-only, FieldValue.increment creates on first call.
      incrementGameStats(tx, gameStatsRef(p.userId, gameId), gameName, p.isWinner, playedAt);

      // 2d. User library — upsert using the snapshot fetched in Phase 1.
      upsertUserLibrary(
        tx,
        userLibraryRef(p.userId, gameId),
        libSnapByUserId.get(p.userId)!,
        gameName,
        p.isWinner,
        playedAt
      );
    }
  });

  return { playId: playRef.id } satisfies CreatePlayResult;
});
