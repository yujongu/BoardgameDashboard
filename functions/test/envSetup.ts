/**
 * Jest setupFiles entry — runs once per worker, before the test file's module
 * graph is evaluated.
 *
 * WHY require() instead of import:
 * TypeScript `import` statements compile to require() calls that ts-jest hoists
 * to the very top of the file, before any other code.  Using require() here
 * keeps the call exactly where it is written so that FIRESTORE_EMULATOR_HOST
 * is guaranteed to be set before any firebase-admin code runs.
 *
 * WHY no credential:
 * @google-cloud/firestore automatically switches to an EmulatorCredential when
 * FIRESTORE_EMULATOR_HOST is set.  No explicit credential is needed or wanted;
 * providing one would only risk masking the emulator-detection path.
 */

// 1. Set the emulator host FIRST — before any firebase-admin module code runs.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

// 2. Load firebase-admin only after the env var is in place.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const admin = require("firebase-admin") as typeof import("firebase-admin");

// 3. Pre-initialise so db.ts's guard (`if (!admin.apps.length)`) skips its own
//    initializeApp() call and never attempts ADC.
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "demo-boardgame-test" });
}
