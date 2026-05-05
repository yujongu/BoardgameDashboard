/**
 * Direct Firestore seed helpers for setting up test state without going through
 * Cloud Functions.  Used by reads tests where we need precise control over
 * document shape (timestamps, ordering) and don't want to trigger stats writes.
 */

import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../setup";

// ─── Play seeding ─────────────────────────────────────────────────────────────

export interface SeedPlayOptions {
  gameId: string;
  gameName: string;
  /** ISO 8601 string */
  playedAt: string;
  createdBy: string;
  participantIds: string[];
  participantCount?: number;
  location?: string;
  notes?: string;
}

/**
 * Seeds a play document directly, bypassing transactions and stats updates.
 * Useful for read-function tests where stats consistency isn't under test.
 */
export async function seedPlay(
  playId: string,
  opts: SeedPlayOptions
): Promise<void> {
  await db
    .collection("plays")
    .doc(playId)
    .set({
      gameId: opts.gameId,
      gameName: opts.gameName,
      playedAt: Timestamp.fromDate(new Date(opts.playedAt)),
      createdBy: opts.createdBy,
      participantCount: opts.participantCount ?? opts.participantIds.length,
      participantIds: opts.participantIds,
      ...(opts.location !== undefined && { location: opts.location }),
      ...(opts.notes !== undefined && { notes: opts.notes }),
      createdAt: FieldValue.serverTimestamp(),
    });
}

export interface SeedParticipantOptions {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
  rank?: number;
}

/**
 * Seeds a participant document into a play's subcollection.
 */
export async function seedParticipant(
  playId: string,
  opts: SeedParticipantOptions
): Promise<void> {
  await db
    .collection("plays")
    .doc(playId)
    .collection("participants")
    .doc()
    .set({
      userId: opts.userId,
      name: opts.name,
      isWinner: opts.isWinner,
      ...(opts.score !== undefined && { score: opts.score }),
      ...(opts.rank !== undefined && { rank: opts.rank }),
      joinedAt: FieldValue.serverTimestamp(),
    });
}

// ─── Library seeding ──────────────────────────────────────────────────────────

export interface SeedLibraryOptions {
  gameName: string;
  playCount: number;
  winCount: number;
  /** Explicit Date to control sort order in getMyLibrary tests */
  lastPlayedAt: Date;
  firstPlayedAt?: Date;
}

/**
 * Seeds a user library document directly.
 * Use when you need deterministic timestamps for ordering assertions.
 */
export async function seedLibrary(
  userId: string,
  gameId: string,
  opts: SeedLibraryOptions
): Promise<void> {
  await db
    .collection("users")
    .doc(userId)
    .collection("library")
    .doc(gameId)
    .set({
      gameId,
      gameName: opts.gameName,
      playCount: opts.playCount,
      winCount: opts.winCount,
      lastPlayedAt: Timestamp.fromDate(opts.lastPlayedAt),
      firstPlayedAt: Timestamp.fromDate(opts.firstPlayedAt ?? opts.lastPlayedAt),
      isOwned: false,
    });
}

// ─── Participant input factory ────────────────────────────────────────────────

export function makeParticipant(
  overrides: Partial<{
    userId: string | null;
    name: string;
    isWinner: boolean;
    score: number;
  }>
): {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
} {
  return {
    userId: overrides.userId !== undefined ? overrides.userId : "u1",
    name: overrides.name ?? "TestPlayer",
    isWinner: overrides.isWinner ?? false,
    ...(overrides.score !== undefined && { score: overrides.score }),
  };
}
