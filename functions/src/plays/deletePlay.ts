import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "../shared/db";
import {
  decrementCoopPlays,
  decrementGameStats,
  decrementStats,
  decrementUserLibrary,
  gameStatsRef,
  statsRef,
  userLibraryRef,
} from "../shared/helpers";
import { assertParticipant } from "../shared/auth";
import { ParticipantDocument, PlayDocument } from "../shared/types";

// ─── Input / output types ─────────────────────────────────────────────────────

interface DeletePlayData {
  playId: string;
}

interface DeletePlayResult {
  success: true;
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: DeletePlayData): void {
  if (!data.playId?.trim()) {
    throw new HttpsError("invalid-argument", "playId is required.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const deletePlay = onCall<DeletePlayData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  // Captured before the transaction closure so narrowing survives.
  const uid = request.auth.uid;
  const playRef = db.collection("plays").doc(data.playId);

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ ─────────────────────────────────────────────────────────
    //
    // Reads are sequential here because each step's output is needed to
    // build the next read's references — this dependency chain is unavoidable.
    // No writes are queued between reads, so the SDK constraint is satisfied.

    // Step 1: play document.
    const playSnap = await tx.get(playRef);

    // Idempotent — if already deleted, treat as success.
    if (!playSnap.exists) return;

    const play = playSnap.data() as PlayDocument;
    assertParticipant(play, uid);

    const { gameId } = play;

    // Co-op writes only stats.totalCoopPlays — no gameStats, library, or win
    // figures (see createPlay). Rolling those back would subtract counts the
    // play never added: totalGamesPlayed would fall below the library sum, and
    // a library entry would be deleted outright once decremented to 0.
    const coop = play.mode === "coop";

    // Step 2: participants subcollection (query read — all docs in one RPC).
    const participantsSnap = await tx.get(
      playRef.collection("participants")
    );

    // Step 3: aggregate per userId — count appearances and wins.
    // Deduplication is necessary: the same userId can appear multiple times
    // (e.g. a player tracked under two participant slots), and a per-row
    // decrement would apply the rollback multiple times to the same documents.
    const aggregates = new Map<string, { count: number; wins: number }>();

    for (const doc of participantsSnap.docs) {
      const { userId, isWinner } = doc.data() as ParticipantDocument;
      if (userId === null) continue; // guests have no derived data

      const agg = aggregates.get(userId) ?? { count: 0, wins: 0 };
      agg.count += 1;
      agg.wins  += isWinner ? 1 : 0;
      aggregates.set(userId, agg);
    }

    // Unique registered users in stable (insertion) order.
    const uniqueUsers = [...aggregates.entries()].map(([userId, agg]) => ({
      userId,
      count: agg.count,
      wins: agg.wins,
    }));

    // Step 4: build derived refs for unique userIds — fixed order:
    //         [stats × N] [gameStats × N] [library × N]
    // Co-op only ever touched the stats document, so it reads only that.
    const sRefs  = uniqueUsers.map((u) => statsRef(u.userId));
    const gsRefs = coop ? [] : uniqueUsers.map((u) => gameStatsRef(u.userId, gameId));
    const ulRefs = coop ? [] : uniqueUsers.map((u) => userLibraryRef(u.userId, gameId));

    // Step 5: fetch all derived documents in ONE tx.getAll() call.
    const allDerivedRefs = [...sRefs, ...gsRefs, ...ulRefs];
    const allDerivedSnaps =
      allDerivedRefs.length > 0 ? await tx.getAll(...allDerivedRefs) : [];

    // Slice back into groups — order mirrors allDerivedRefs construction.
    const n          = uniqueUsers.length;
    const statsSnaps = allDerivedSnaps.slice(0, n);
    const gsSnaps    = coop ? [] : allDerivedSnaps.slice(n, 2 * n);
    const ulSnaps    = coop ? [] : allDerivedSnaps.slice(2 * n);

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    // 1. Roll back derived data using aggregated counts per unique userId.
    for (let i = 0; i < uniqueUsers.length; i++) {
      const { count, wins } = uniqueUsers[i];

      if (coop) {
        decrementCoopPlays(tx, sRefs[i], statsSnaps[i], count);
        continue;
      }

      decrementStats(tx, sRefs[i], statsSnaps[i], count, wins);
      decrementGameStats(tx, gsRefs[i], gsSnaps[i], count, wins);
      decrementUserLibrary(tx, ulRefs[i], ulSnaps[i], count, wins);
    }

    // 2. Delete all participant documents (registered and guests).
    for (const doc of participantsSnap.docs) {
      tx.delete(doc.ref);
    }

    // 3. Delete the play document last.
    tx.delete(playRef);
  });

  return { success: true } satisfies DeletePlayResult;
});
