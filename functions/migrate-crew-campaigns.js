#!/usr/bin/env node
'use strict';

/**
 * One-time migration: legacy per-user Crew campaign sheets
 *   users/{uid}/campaigns/{gameId}   { crewMembers, currentMission }
 * become shared, table-scoped campaigns
 *   campaigns/{autoId}               { gameId, gameName, memberIds, roster,
 *                                      stages, createdBy, migratedFrom }
 *
 * Each legacy doc yields one campaign owned by that user (memberIds = [uid]).
 * Missions 1..(currentMission-1) are marked completed. gameName is resolved
 * from boardGames/{gameId}, falling back to the gameId.
 *
 * Idempotent: a `migratedFrom` marker records the source path, and a doc that
 * has already been migrated is skipped, so re-running is safe.
 *
 * Usage (from the functions/ directory):
 *   node migrate-crew-campaigns.js
 *
 * Authentication — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node migrate-crew-campaigns.js
 *   gcloud auth application-default login  → then run without GOOGLE_APPLICATION_CREDENTIALS
 */

const { initializeApp, getApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'gameshelf-283dc';

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

async function gameNameFor(gameId) {
  const snap = await db.collection('boardGames').doc(gameId).get();
  return snap.exists ? (snap.data().name ?? gameId) : gameId;
}

function buildStages(currentMission) {
  const stages = {};
  for (let i = 1; i < currentMission; i++) {
    stages[String(i)] = { completed: true, sessionCount: 0 };
  }
  return stages;
}

async function main() {
  console.log('Project:', getApp().options.projectId);
  console.log('Emulator host:', process.env.FIRESTORE_EMULATOR_HOST ?? '(none)');

  // collectionGroup('campaigns') matches BOTH the new root `campaigns` and the
  // legacy `users/{uid}/campaigns` subcollections. Legacy docs are the ones
  // nested under a user (parent.parent is the user doc) with a currentMission.
  const all = await db.collectionGroup('campaigns').get();

  let processed = 0;
  let migrated = 0;
  let skipped = 0;

  for (const doc of all.docs) {
    const userDoc = doc.ref.parent.parent; // users/{uid} for legacy docs
    if (userDoc === null) continue;         // a root campaigns/{id} doc — skip

    const data = doc.data();
    if (data.currentMission === undefined) continue; // not a legacy Crew sheet

    processed++;
    const legacyPath = doc.ref.path;
    const uid = userDoc.id;
    const gameId = doc.id;

    const existing = await db
      .collection('campaigns')
      .where('migratedFrom', '==', legacyPath)
      .limit(1)
      .get();
    if (!existing.empty) {
      console.log(`  [SKIP] ${legacyPath} — already migrated`);
      skipped++;
      continue;
    }

    const gameName = await gameNameFor(gameId);
    const roster = Array.isArray(data.crewMembers) ? data.crewMembers : [];
    const currentMission = Number(data.currentMission) || 1;

    await db.collection('campaigns').add({
      gameId,
      gameName,
      memberIds: [uid],
      roster,
      stages: buildStages(currentMission),
      createdBy: uid,
      migratedFrom: legacyPath,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    migrated++;
    console.log(`  [OK] ${legacyPath} → campaigns (mission ${currentMission}, ${roster.length} crew)`);
  }

  console.log('\nMigration complete.');
  console.log(`  Legacy sheets processed : ${processed}`);
  console.log(`  Migrated                : ${migrated}`);
  console.log(`  Skipped (already done)  : ${skipped}`);
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
