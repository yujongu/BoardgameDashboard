#!/usr/bin/env node
'use strict';

/**
 * One-time backfill: for all Firebase Auth users, write:
 *   - users/{uid}         { name, name_lower, photoUrl }
 *   - userSearch/{uid}    { name, name_lower, photoUrl }
 *
 * Safe to run multiple times — writes are idempotent (set, not create).
 * Users with no displayName in Auth are skipped.
 *
 * Usage (from the functions/ directory):
 *   node backfill-user-search.js
 *
 * Authentication — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node backfill-user-search.js
 *   gcloud auth application-default login  → then run without GOOGLE_APPLICATION_CREDENTIALS
 */

const { initializeApp, getApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'gameshelf-283dc';
const BATCH_SIZE = 500;

// ─── Init ─────────────────────────────────────────────────────────────────────

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();
const auth = getAuth();

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Project:', getApp().options.projectId);
  console.log('Emulator host:', process.env.FIRESTORE_EMULATOR_HOST ?? '(none)');

  // Collect all Auth users via paginated listUsers.
  const users = [];
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    users.push(...result.users);
    pageToken = result.pageToken;
  } while (pageToken);

  console.log(`Found ${users.length} Auth user(s).`);

  let processed = 0;
  let skipped = 0;
  let written = 0;

  for (let i = 0; i < users.length; i += BATCH_SIZE) {
    const chunk = users.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    let batchCount = 0;

    for (const user of chunk) {
      processed++;
      const name = user.displayName?.trim() ?? '';

      if (!name) {
        console.warn(`  [SKIP] ${user.uid} — no displayName in Auth`);
        skipped++;
        continue;
      }

      const doc = {
        name,
        name_lower: name.toLowerCase(),
        photoUrl: user.photoURL ?? null,
      };

      batch.set(db.collection('users').doc(user.uid), doc);
      batch.set(db.collection('userSearch').doc(user.uid), doc);
      batchCount += 2;
    }

    if (batchCount > 0) {
      await batch.commit();
      written += batchCount / 2; // count user pairs, not individual writes
    }

    console.log(`  Progress: ${processed}/${users.length} processed, ${written} written, ${skipped} skipped`);
  }

  console.log('\nBackfill complete.');
  console.log(`  Total processed : ${processed}`);
  console.log(`  Written         : ${written} user(s) → users + userSearch`);
  console.log(`  Skipped         : ${skipped}`);
}

main().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
