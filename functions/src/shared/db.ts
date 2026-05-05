import * as admin from "firebase-admin";

if (!admin.apps.length) {
  // When the Firestore Emulator is active, FIRESTORE_EMULATOR_HOST is set and
  // @google-cloud/firestore uses its own EmulatorCredential — no ADC is needed
  // or wanted.  Passing only projectId prevents any attempt to resolve implicit
  // Application Default Credentials, which would fail outside GCP and in CI.
  //
  // In production (Cloud Functions), FIRESTORE_EMULATOR_HOST is absent and
  // admin.initializeApp() receives no options so it uses the runtime-injected
  // FIREBASE_CONFIG and the metadata-server credential as intended.
  admin.initializeApp(
    process.env.FIRESTORE_EMULATOR_HOST
      ? { projectId: "demo-boardgame-test" }
      : undefined
  );
}

export const db = admin.firestore();
