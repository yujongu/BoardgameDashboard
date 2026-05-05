import {
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import { db } from "./db";
import { GameStatsDocument, StatsDocument, UserLibraryDocument } from "./types";

// ─── TWO-PHASE TRANSACTION CONTRACT ──────────────────────────────────────────
//
// Every write transaction must follow this strict two-phase structure:
//
//   PHASE 1 — READ (userLibrary only):
//     stats and gameStats are NEVER read — FieldValue.increment + merge
//     handles creation and incrementing in a single atomic write.
//     Only userLibrary requires a snapshot, to detect first play and
//     set firstPlayedAt correctly (Firestore merge cannot "set if absent").
//     Fetch all library snapshots in one tx.getAll() call before any writes.
//
//   PHASE 2 — WRITE:
//     Helpers are pure write-only functions — they call tx.set/update/delete.
//     No tx.get() calls may occur in this phase.
//
// This guarantees compliance with the Firestore Admin SDK constraint:
//   "Firestore transactions require all reads to be executed before all writes."
//   (throws synchronously inside tx.get() when _writeBatch is non-empty)
//
// Read budget per transaction:
//   createPlay  →  1 tx.getAll() containing N userLibrary docs (N = registered participants)
//   deletePlay  →  1 tx.getAll() containing the play doc + N stats + N gameStats + N library docs
//   updatePlay  →  same as deletePlay (must read old values to decrement)
//
// See usage example at the bottom of this file.
//
// ─────────────────────────────────────────────────────────────────────────────

// ─── Write-only refs — NEVER passed to tx.get() ──────────────────────────────
// stats and gameStats are always written via FieldValue.increment + merge.
// Build these in Phase 2; no snapshot is needed.

export const statsRef = (userId: string): DocumentReference =>
  db.collection("stats").doc(userId);

export const gameStatsRef = (userId: string, gameId: string): DocumentReference =>
  db.collection("stats").doc(userId).collection("gameStats").doc(gameId);

// ─── Read-phase refs — fetch via tx.getAll() in Phase 1 ──────────────────────
// userLibrary is the only collection that requires a pre-fetched snapshot.

export const userLibraryRef = (userId: string, gameId: string): DocumentReference =>
  db.collection("users").doc(userId).collection("library").doc(gameId);

// ─── Stats helpers ────────────────────────────────────────────────────────────

/**
 * Increments aggregated lifetime stats for a user.
 * Creates the stats document on first call (FieldValue.increment + merge).
 * No snapshot required.
 */
export function incrementStats(
  tx: Transaction,
  ref: DocumentReference,
  isWinner: boolean
): void {
  tx.set(
    ref,
    {
      totalGamesPlayed: FieldValue.increment(1),
      totalWins: FieldValue.increment(isWinner ? 1 : 0),
      lastPlayedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * Decrements aggregated lifetime stats for a user by pre-computed counts.
 * `count` = number of plays being removed; `wins` = number of those that were wins.
 * `snap` must be fetched in Phase 1. Values are clamped at 0.
 * `lastPlayedAt` is left unchanged — recalculating it requires a query
 * across all remaining plays, which cannot be done inside a transaction.
 * No-op if the document does not exist.
 */
export function decrementStats(
  tx: Transaction,
  ref: DocumentReference,
  snap: DocumentSnapshot,
  count: number,
  wins: number
): void {
  if (!snap.exists) return;

  const data = snap.data() as StatsDocument;
  tx.update(ref, {
    totalGamesPlayed: Math.max(0, data.totalGamesPlayed - count),
    totalWins: Math.max(0, data.totalWins - wins),
  });
}

// ─── Game Stats helpers ───────────────────────────────────────────────────────

/**
 * Increments (or creates) the per-user per-game stats document.
 * `gameId` is derived from ref.id. `gameName` is refreshed as a snapshot
 * on every call so it stays current if the game is renamed.
 * No snapshot required.
 */
export function incrementGameStats(
  tx: Transaction,
  ref: DocumentReference,
  gameName: string,
  isWinner: boolean
): void {
  tx.set(
    ref,
    {
      gameId: ref.id,
      gameName,
      playCount: FieldValue.increment(1),
      winCount: FieldValue.increment(isWinner ? 1 : 0),
      lastPlayedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * Decrements the per-user per-game stats document by pre-computed counts.
 * `count` = number of plays being removed; `wins` = number of those that were wins.
 * `snap` must be fetched in Phase 1. Values are clamped at 0.
 * `lastPlayedAt` is left unchanged — recalculating requires a separate query.
 * No-op if the document does not exist.
 */
export function decrementGameStats(
  tx: Transaction,
  ref: DocumentReference,
  snap: DocumentSnapshot,
  count: number,
  wins: number
): void {
  if (!snap.exists) return;

  const data = snap.data() as GameStatsDocument;
  tx.update(ref, {
    playCount: Math.max(0, data.playCount - count),
    winCount: Math.max(0, data.winCount - wins),
  });
}

// ─── User Library helpers ─────────────────────────────────────────────────────

/**
 * Upserts the user's library entry for a game.
 * `snap` must be fetched in Phase 1.
 * `gameId` is derived from ref.id.
 *
 * - No existing document: creates with firstPlayedAt = now.
 * - Existing document: increments counters and updates lastPlayedAt.
 *   firstPlayedAt is never overwritten once set.
 *
 * A pre-fetched snapshot is required because Firestore merge has no
 * "set field only if absent" operation — existence must be checked explicitly.
 */
export function upsertUserLibrary(
  tx: Transaction,
  ref: DocumentReference,
  snap: DocumentSnapshot,
  gameName: string,
  isWinner: boolean
): void {
  if (!snap.exists) {
    tx.set(ref, {
      gameId: ref.id,
      gameName,
      playCount: 1,
      winCount: isWinner ? 1 : 0,
      firstPlayedAt: FieldValue.serverTimestamp(),
      lastPlayedAt: FieldValue.serverTimestamp(),
      isOwned: false,
    });
    return;
  }

  tx.update(ref, {
    gameName,
    playCount: FieldValue.increment(1),
    winCount: FieldValue.increment(isWinner ? 1 : 0),
    lastPlayedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Decrements the user's library entry for a game by pre-computed counts.
 * `count` = number of plays being removed; `wins` = number of those that were wins.
 * `snap` must be fetched in Phase 1. Values are clamped at 0.
 *
 * When playCount reaches 0: deletes the document entirely.
 * When plays remain: decrements counters only. `lastPlayedAt` is left unchanged —
 * setting it correctly would require querying the next most-recent play.
 * No-op if the document does not exist.
 */
export function decrementUserLibrary(
  tx: Transaction,
  ref: DocumentReference,
  snap: DocumentSnapshot,
  count: number,
  wins: number
): void {
  if (!snap.exists) return;

  const data = snap.data() as UserLibraryDocument;
  const newPlayCount = Math.max(0, data.playCount - count);
  const newWinCount  = Math.max(0, data.winCount - wins);

  if (newPlayCount === 0) {
    tx.delete(ref);
    return;
  }

  tx.update(ref, {
    playCount: newPlayCount,
    winCount: newWinCount,
  });
}

// ─── Usage example: createPlay ────────────────────────────────────────────────
//
// Demonstrates the optimised read phase for a multi-participant session.
// Total Firestore reads = 1 tx.getAll() with N docs (one per registered participant).
// stats and gameStats produce ZERO reads.
//
//   type Participant = { userId: string | null; isWinner: boolean; /* ... */ };
//
//   async function createPlay(
//     gameId: string,
//     gameName: string,
//     participants: Participant[],
//   ) {
//     await db.runTransaction(async (tx) => {
//
//       // ── Phase 1: collect library refs (registered participants only) ─────
//       // Guests have no stats or library entries to update.
//       const registered = participants.filter(
//         (p): p is Participant & { userId: string } => p.userId !== null
//       );
//
//       const libRefs = registered.map(p => userLibraryRef(p.userId, gameId));
//
//       // ── Phase 1: single tx.getAll() — only reads in the entire transaction ─
//       // stats and gameStats are intentionally absent: FieldValue.increment +
//       // merge handles create-or-increment atomically with no prior read.
//       const libSnaps = libRefs.length > 0 ? await tx.getAll(...libRefs) : [];
//
//       // Map userId → snapshot for O(1) lookup in Phase 2.
//       const libSnapByUserId = new Map(
//         registered.map((p, i) => [p.userId, libSnaps[i]])
//       );
//
//       // ── Phase 2: ALL writes — no tx.get() calls past this point ──────────
//       const playRef = db.collection("plays").doc();
//       tx.set(playRef, { /* PlayDocument fields */ });
//
//       for (const p of participants) {
//         tx.set(playRef.collection("participants").doc(), { /* ParticipantDocument */ });
//
//         if (p.userId === null) continue; // guest — no stats to update
//
//         incrementStats(tx, statsRef(p.userId), p.isWinner);
//         incrementGameStats(tx, gameStatsRef(p.userId, gameId), gameName, p.isWinner);
//         upsertUserLibrary(
//           tx,
//           userLibraryRef(p.userId, gameId),
//           libSnapByUserId.get(p.userId)!,
//           gameName,
//           p.isWinner,
//         );
//       }
//     });
//   }
//
// ─────────────────────────────────────────────────────────────────────────────
