#!/usr/bin/env node
'use strict';

/**
 * Deletes all Firestore data except protected collections.
 *
 * Usage (from the functions/ directory):
 *   node clear-firestore.js
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'gameshelf-283dc';
const PROTECTED = new Set(['boardGames']);

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

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
