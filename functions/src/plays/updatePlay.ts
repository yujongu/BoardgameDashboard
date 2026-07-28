import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import { db } from "../shared/db";
import { gameStatsRef, statsRef, userLibraryRef } from "../shared/helpers";
import { assertParticipant } from "../shared/auth";
import { ParticipantDocument, PlayDocument, UserLibraryDocument } from "../shared/types";

// ─── Input / output types ─────────────────────────────────────────────────────

interface ParticipantInput {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
}

interface UpdatePlayData {
  playId: string;
  gameId: string;
  gameName: string;
  /** ISO 8601 string — converted to Firestore Timestamp server-side. */
  playedAt: string;
  participants: ParticipantInput[];
  location?: string;
  notes?: string;
}

interface UpdatePlayResult {
  success: true;
}

// ─── Internal types ───────────────────────────────────────────────────────────

interface Aggregate {
  count: number;
  wins: number;
}

/** One unit of change to apply to a specific (userId, gameId) pair. */
interface DeltaEntry {
  userId: string;
  gameId: string;
  gameName: string;
  deltaCount: number;
  deltaWins: number;
}

// ─── Aggregation ──────────────────────────────────────────────────────────────

/**
 * Builds a per-userId aggregate (play count + win count) from a list of
 * participants. Guests (userId === null) are excluded.
 */
function buildAggregateMap(
  items: Array<{ userId: string | null; isWinner: boolean }>
): Map<string, Aggregate> {
  const map = new Map<string, Aggregate>();
  for (const item of items) {
    if (item.userId === null) continue;
    const agg = map.get(item.userId) ?? { count: 0, wins: 0 };
    agg.count += 1;
    agg.wins += item.isWinner ? 1 : 0;
    map.set(item.userId, agg);
  }
  return map;
}

// ─── Diff computation ─────────────────────────────────────────────────────────

/**
 * Computes the list of deltas to apply given the old and new state.
 *
 * Same game: produces one delta per userId where count or wins changed.
 * Game changed: produces full-rollback deltas for the old game and
 *   full-setup deltas for the new game. A user present in both generates
 *   two entries (different gameIds), which net to zero in the stats layer
 *   and correctly update two separate gameStats/library documents.
 *
 * Entries where both deltaCount and deltaWins are zero are excluded.
 */
function computeDeltas(
  oldAgg: Map<string, Aggregate>,
  oldGameId: string,
  oldGameName: string,
  newAgg: Map<string, Aggregate>,
  newGameId: string,
  newGameName: string
): DeltaEntry[] {
  const deltas: DeltaEntry[] = [];

  if (oldGameId === newGameId) {
    const allUserIds = new Set([...oldAgg.keys(), ...newAgg.keys()]);
    for (const userId of allUserIds) {
      const old = oldAgg.get(userId) ?? { count: 0, wins: 0 };
      const next = newAgg.get(userId) ?? { count: 0, wins: 0 };
      const deltaCount = next.count - old.count;
      const deltaWins = next.wins - old.wins;
      if (deltaCount !== 0 || deltaWins !== 0) {
        deltas.push({ userId, gameId: newGameId, gameName: newGameName, deltaCount, deltaWins });
      }
    }
  } else {
    // Full rollback of old game participants.
    for (const [userId, agg] of oldAgg) {
      deltas.push({
        userId,
        gameId: oldGameId,
        gameName: oldGameName,
        deltaCount: -agg.count,
        deltaWins: -agg.wins,
      });
    }
    // Full setup of new game participants.
    for (const [userId, agg] of newAgg) {
      deltas.push({
        userId,
        gameId: newGameId,
        gameName: newGameName,
        deltaCount: agg.count,
        deltaWins: agg.wins,
      });
    }
  }

  return deltas;
}

// ─── Local write-only helpers ─────────────────────────────────────────────────

/**
 * Applies a signed delta to lifetime stats via FieldValue.increment.
 * No snapshot required — create-or-update is handled by merge.
 *
 * Note: a negative delta on a missing document would produce sub-zero values.
 * This cannot happen when all plays are created through createPlay first.
 */
function applyStatsDelta(
  tx: Transaction,
  ref: DocumentReference,
  deltaCount: number,
  deltaWins: number,
  playedAt: Timestamp
): void {
  tx.set(
    ref,
    {
      totalGamesPlayed: FieldValue.increment(deltaCount),
      totalWins: FieldValue.increment(deltaWins),
      lastPlayedAt: playedAt,
    },
    { merge: true }
  );
}

/**
 * Applies a signed delta to per-game stats via FieldValue.increment.
 * `gameId` is derived from ref.id. `gameName` snapshot is refreshed on each write.
 * No snapshot required — create-or-update is handled by merge.
 */
function applyGameStatsDelta(
  tx: Transaction,
  ref: DocumentReference,
  gameName: string,
  deltaCount: number,
  deltaWins: number,
  playedAt: Timestamp
): void {
  tx.set(
    ref,
    {
      gameId: ref.id,
      gameName,
      playCount: FieldValue.increment(deltaCount),
      winCount: FieldValue.increment(deltaWins),
      lastPlayedAt: playedAt,
    },
    { merge: true }
  );
}

/**
 * Applies a signed delta to a user's library entry.
 * `snap` must be fetched in Phase 1. Values are clamped at 0.
 *
 * - Document absent + deltaCount > 0: creates the entry with firstPlayedAt = now.
 * - Document absent + deltaCount ≤ 0: no-op (guards against data inconsistency).
 * - Document present + newPlayCount === 0: deletes the document.
 * - Document present + newPlayCount > 0: updates counts; firstPlayedAt is unchanged.
 */
function applyLibraryDelta(
  tx: Transaction,
  ref: DocumentReference,
  snap: DocumentSnapshot,
  gameName: string,
  deltaCount: number,
  deltaWins: number,
  playedAt: Timestamp
): void {
  if (!snap.exists) {
    if (deltaCount <= 0) return;
    tx.set(ref, {
      gameId: ref.id,
      gameName,
      playCount: deltaCount,
      winCount: Math.max(0, deltaWins),
      firstPlayedAt: playedAt,
      lastPlayedAt: playedAt,
      isOwned: false,
    });
    return;
  }

  const data = snap.data() as UserLibraryDocument;
  const newPlayCount = Math.max(0, data.playCount + deltaCount);
  const newWinCount = Math.max(0, data.winCount + deltaWins);

  if (newPlayCount === 0) {
    tx.delete(ref);
    return;
  }

  tx.update(ref, {
    gameName,
    playCount: newPlayCount,
    winCount: newWinCount,
    lastPlayedAt: playedAt,
    ...(!data.firstPlayedAt && { firstPlayedAt: playedAt }),
  });
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: UpdatePlayData): void {
  if (!data.playId?.trim()) {
    throw new HttpsError("invalid-argument", "playId is required.");
  }
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

export const updatePlay = onCall<UpdatePlayData>({ minInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const { playId, gameId, gameName, participants, location, notes } = data;
  const playedAt = Timestamp.fromDate(new Date(data.playedAt));
  // Captured before the transaction closure so narrowing survives.
  const uid = request.auth.uid;
  const playRef = db.collection("plays").doc(playId);

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ ─────────────────────────────────────────────────────────

    // Steps 1 & 2: fetch play doc and participants subcollection in parallel.
    const [playSnap, participantsSnap] = await Promise.all([
      tx.get(playRef),
      tx.get(playRef.collection("participants")),
    ]);

    if (!playSnap.exists) {
      throw new HttpsError("not-found", `Play ${playId} does not exist.`);
    }
    const oldPlay = playSnap.data() as PlayDocument;
    assertParticipant(oldPlay, uid);

    // Step 3: build old aggregate from existing participant docs.
    const oldAgg = buildAggregateMap(
      participantsSnap.docs.map((doc) => doc.data() as ParticipantDocument)
    );

    // Step 4: build new aggregate from input.
    const newAgg = buildAggregateMap(participants);

    // Step 5: compute per-(userId, gameId) deltas.
    // Handles both same-game edits and game changes transparently.
    const deltas = computeDeltas(
      oldAgg, oldPlay.gameId, oldPlay.gameName,
      newAgg, gameId, gameName
    );

    // Step 6: collect unique (userId, gameId) library refs from the diff.
    // stats and gameStats are NOT read — FieldValue.increment handles those.
    const libKeyToRef = new Map<string, DocumentReference>();
    for (const d of deltas) {
      const key = `${d.userId}:${d.gameId}`;
      if (!libKeyToRef.has(key)) {
        libKeyToRef.set(key, userLibraryRef(d.userId, d.gameId));
      }
    }

    // Step 7: fetch all library snapshots in ONE tx.getAll() call.
    const libEntries = [...libKeyToRef.entries()];
    const libRefs    = libEntries.map(([, ref]) => ref);
    const libSnaps   = libRefs.length > 0 ? await tx.getAll(...libRefs) : [];
    const libSnapByKey = new Map(libEntries.map(([key], i) => [key, libSnaps[i]]));

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    // 1. Apply stat deltas.
    //
    //    Stats are per userId (not per gameId). When a game changes, the same
    //    userId can produce two delta entries (old + new game). Aggregating
    //    here ensures the stats doc is written exactly ONCE per userId,
    //    avoiding conflicting writes in the same transaction.
    const statsDeltaByUserId = new Map<string, { deltaCount: number; deltaWins: number }>();
    for (const d of deltas) {
      const agg = statsDeltaByUserId.get(d.userId) ?? { deltaCount: 0, deltaWins: 0 };
      agg.deltaCount += d.deltaCount;
      agg.deltaWins  += d.deltaWins;
      statsDeltaByUserId.set(d.userId, agg);
    }

    for (const [userId, { deltaCount, deltaWins }] of statsDeltaByUserId) {
      if (deltaCount !== 0 || deltaWins !== 0) {
        applyStatsDelta(tx, statsRef(userId), deltaCount, deltaWins, playedAt);
      }
    }

    // 2. Apply gameStats and library deltas.
    //    Each entry in `deltas` has a unique (userId, gameId) — no duplicate refs.
    for (const d of deltas) {
      const libKey = `${d.userId}:${d.gameId}`;
      applyGameStatsDelta(
        tx,
        gameStatsRef(d.userId, d.gameId),
        d.gameName,
        d.deltaCount,
        d.deltaWins,
        playedAt
      );
      applyLibraryDelta(
        tx,
        libKeyToRef.get(libKey)!,
        libSnapByKey.get(libKey)!,
        d.gameName,
        d.deltaCount,
        d.deltaWins,
        playedAt
      );
    }

    // 3. Update the play document.
    const newParticipantIds = participants
      .filter((p) => p.userId !== null)
      .map((p) => p.userId as string);

    tx.update(playRef, {
      gameId,
      gameName,
      playedAt,
      participantCount: participants.length,
      participantIds: newParticipantIds,
      // Present value overwrites; absent/empty clears the field.
      location: location ? location : FieldValue.delete(),
      notes: notes ? notes : FieldValue.delete(),
    });

    // 4. Replace participants subcollection: delete all old, create all new.
    for (const doc of participantsSnap.docs) {
      tx.delete(doc.ref);
    }
    for (const p of participants) {
      tx.set(playRef.collection("participants").doc(), {
        userId: p.userId,
        name: p.name,
        isWinner: p.isWinner,
        ...(p.score !== undefined && { score: p.score }),
        joinedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { success: true } satisfies UpdatePlayResult;
});
