#!/usr/bin/env node
'use strict';

/**
 * Deletes all Firestore data except protected collections.
 *
 * Usage (from the functions/ directory):
 *   node clear-firestore.js
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'gameshelf-283dc';
const PROTECTED = new Set(['boardGames']);

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clear() {
  const collections = await db.listCollections();

  console.log(`Project: ${PROJECT_ID}\n`);

  for (const col of collections) {
    if (PROTECTED.has(col.id)) {
      console.log(`[SKIP]   ${col.id}`);
      continue;
    }
    process.stdout.write(`[DELETE] ${col.id}... `);
    await db.recursiveDelete(col);
    console.log('done');
  }

  console.log('\nDone.');
}

clear().catch((err) => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
