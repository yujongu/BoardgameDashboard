import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../shared/db";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function buildSearchDoc(data: FirebaseFirestore.DocumentData) {
  const name = typeof data.name === "string" ? data.name : "";
  return {
    name,
    name_lower: name.toLowerCase(),
    photoUrl: typeof data.photoUrl === "string" ? data.photoUrl : null,
  };
}

// ─── onCreate ─────────────────────────────────────────────────────────────────

export const syncUserSearchOnCreate = onDocumentCreated("users/{userId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const userId = event.params.userId;
  await db.collection("userSearch").doc(userId).set(buildSearchDoc(data));
});

// ─── onUpdate ─────────────────────────────────────────────────────────────────

export const syncUserSearchOnUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before.data() ?? {};
  const after = event.data?.after.data() ?? {};

  // Skip write if search-relevant fields are unchanged.
  if (before.name === after.name && before.photoUrl === after.photoUrl) return;

  const userId = event.params.userId;
  await db.collection("userSearch").doc(userId).set(buildSearchDoc(after));
});
