/**
 * Shared test utilities: admin Firestore instance, DB clearing, and
 * Firestore read helpers for assertions.
 *
 * Import this module before importing any callable helpers so TypeScript's
 * module resolution loads envSetup (via jest setupFiles) first.
 */

import { getFirestore } from "firebase-admin/firestore";

export const PROJECT_ID = "demo-boardgame-test";
export const EMULATOR_HOST = "127.0.0.1:8080";

// Uses the default app initialised by envSetup.ts
export const db = getFirestore();

// ─── DB management ────────────────────────────────────────────────────────────

/**
 * Wipes every document in the Firestore Emulator.
 * Call in beforeEach / afterEach to guarantee test isolation.
 */
export async function clearDb(): Promise<void> {
  const url = `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, { method: "DELETE" });
  if (!res.ok) {
    throw new Error(
      `clearDb failed: ${res.status} ${await res.text()}`
    );
  }
}

// ─── Assertion helpers ────────────────────────────────────────────────────────

export async function getStats(userId: string) {
  const snap = await db.collection("stats").doc(userId).get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

export async function getGameStats(userId: string, gameId: string) {
  const snap = await db
    .collection("stats")
    .doc(userId)
    .collection("gameStats")
    .doc(gameId)
    .get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

export async function getLibrary(userId: string, gameId: string) {
  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("library")
    .doc(gameId)
    .get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

export async function getPlayDoc(playId: string) {
  const snap = await db.collection("plays").doc(playId).get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

export async function getParticipants(playId: string) {
  const snap = await db
    .collection("plays")
    .doc(playId)
    .collection("participants")
    .get();
  return snap.docs.map((d) => d.data() as Record<string, unknown>);
}

export async function playExists(playId: string): Promise<boolean> {
  return (await db.collection("plays").doc(playId).get()).exists;
}
