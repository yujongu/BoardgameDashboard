#!/usr/bin/env node
'use strict';

/**
 * Seed the boardGames collection in production Firestore.
 *
 * Usage (from the functions/ directory):
 *   node seed-board-games.js <path-to-json>
 *
 * Authentication — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed-board-games.js games.json
 *   gcloud auth application-default login  → then run without GOOGLE_APPLICATION_CREDENTIALS
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

const PROJECT_ID = 'gameshelf-283dc';
const COLLECTION = 'boardGames';
const BATCH_SIZE = 500; // Firestore max per batch

// ─── Init ─────────────────────────────────────────────────────────────────────

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

// ─── CLI arg ──────────────────────────────────────────────────────────────────

const jsonPath = process.argv[2];
if (!jsonPath) {
  console.error('Usage: node seed-board-games.js <path-to-json>');
  process.exit(1);
}

// ─── Document builder (maps JSON → BoardGameDocument schema) ─────────────────

function buildDoc(game) {
  if (!game.name) {
    throw new Error(`Missing required field "name" on gameId: "${game.gameId}"`);
  }

  const doc = { name: game.name, name_lower: game.name.toLowerCase() };

  if (game.thumbnailUrl    != null) doc.thumbnailUrl    = game.thumbnailUrl;
  if (game.publisher       != null) doc.publisher       = game.publisher;
  if (game.releaseYear     != null) doc.releaseYear     = game.releaseYear;
  if (game.minPlayers      != null) doc.minPlayers      = game.minPlayers;
  if (game.maxPlayers      != null) doc.maxPlayers      = game.maxPlayers;
  if (game.playTimeMinutes != null) doc.playTimeMinutes = game.playTimeMinutes;
  if (game.createdAt       != null) {
    doc.createdAt = admin.firestore.Timestamp.fromDate(new Date(game.createdAt));
  }

  return doc;
}

// ─── Seed ─────────────────────────────────────────────────────────────────────

async function seed() {
  const raw   = fs.readFileSync(path.resolve(jsonPath), 'utf8');
  const games = JSON.parse(raw);

  if (!Array.isArray(games)) {
    console.error('Error: JSON root must be an array.');
    process.exit(1);
  }

  console.log(`Project  : ${PROJECT_ID}`);
  console.log(`Collection: ${COLLECTION}`);
  console.log(`Games     : ${games.length}\n`);

  let written = 0;
  let skipped = 0;

  for (let i = 0; i < games.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = games.slice(i, i + BATCH_SIZE);

    for (const game of chunk) {
      if (!game.gameId) {
        console.warn(`  [SKIP] Entry at index ${i + chunk.indexOf(game)} has no gameId`);
        skipped++;
        continue;
      }

      const ref = db.collection(COLLECTION).doc(game.gameId);
      batch.set(ref, buildDoc(game));
      written++;
    }

    await batch.commit();
    console.log(`  Committed ${Math.min(i + BATCH_SIZE, games.length)} / ${games.length}`);
  }

  console.log(`\nDone — ${written} written, ${skipped} skipped.`);
}

seed().catch((err) => {
  console.error('\nFatal:', err.message);
  process.exit(1);
});
