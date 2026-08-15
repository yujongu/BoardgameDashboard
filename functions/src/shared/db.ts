import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

if (!getApps().length) {
  // When the Firestore Emulator is active, FIRESTORE_EMULATOR_HOST is set and
  // @google-cloud/firestore uses its own EmulatorCredential — no ADC is needed
  // or wanted.  Passing only projectId prevents any attempt to resolve implicit
  // Application Default Credentials, which would fail outside GCP and in CI.
  //
  // In production (Cloud Functions), FIRESTORE_EMULATOR_HOST is absent and
  // initializeApp() receives no options so it uses the runtime-injected
  // FIREBASE_CONFIG and the metadata-server credential as intended.
  //
  // The projectId MUST match the app that wrote the data: the Firestore emulator
  // partitions data per project id. In the Functions emulator, GCLOUD_PROJECT is
  // the real app project (e.g. gameshelf-283dc); jest pre-initializes the app
  // (so this branch is skipped) but we fall back to the test project regardless.
  initializeApp(
    process.env.FIRESTORE_EMULATOR_HOST
      ? { projectId: process.env.GCLOUD_PROJECT || "demo-boardgame-test" }
      : undefined
  );
}

export const db = getFirestore();
