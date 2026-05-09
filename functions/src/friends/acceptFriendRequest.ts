import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface AcceptFriendRequestData {
  requestId: string;
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: AcceptFriendRequestData): void {
  if (!data.requestId?.trim()) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const acceptFriendRequest = onCall<AcceptFriendRequestData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const uid = request.auth.uid;
  const { requestId } = data;

  // ── Pre-transaction: reads, auth, status validation ───────────────────────

  const requestRef = db.collection("friendRequests").doc(requestId);
  const requestSnap = await requestRef.get();

  if (!requestSnap.exists) {
    throw new HttpsError("not-found", "Friend request not found.");
  }

  const req = requestSnap.data()!;

  if (!req.fromUserId || !req.toUserId) {
    throw new HttpsError("internal", "Friend request document is missing required fields.");
  }

  if (req.toUserId !== uid) {
    throw new HttpsError("permission-denied", "You cannot accept this request.");
  }

  if (req.status === "accepted") {
    return { success: true };
  }

  if (req.status !== "pending") {
    throw new HttpsError("failed-precondition", "Friend request is not in a pending state.");
  }

  const fromUserId = req.fromUserId as string;
  const toUserId = req.toUserId as string;

  if (fromUserId === toUserId) {
    throw new HttpsError("invalid-argument", "Cannot accept a self-friend request.");
  }

  // Snapshot fields written by sendFriendRequest — no users collection reads needed here.
  // If they are absent, the doc predates this design; reject rather than fall back to a join.
  if (typeof req.fromUserName !== "string" || typeof req.toUserName !== "string") {
    throw new HttpsError(
      "failed-precondition",
      "Friend request is missing snapshot fields — cannot accept without name data."
    );
  }

  const fromUserName = req.fromUserName as string;
  const fromUserPhotoUrl = typeof req.fromUserPhotoUrl === "string" ? req.fromUserPhotoUrl : null;
  const toUserName = req.toUserName as string;
  const toUserPhotoUrl = typeof req.toUserPhotoUrl === "string" ? req.toUserPhotoUrl : null;

  const now = Timestamp.now();

  // ── Transaction: friend subcollection reads, then writes ─────────────────
  // This system intentionally avoids joins with users collection to minimize reads and latency.
  // All name/photoUrl data comes from snapshot fields on the request document.

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ ─────────────────────────────────────────────────────────

    const fromUserRef = db.collection("users").doc(fromUserId);
    const toUserRef = db.collection("users").doc(toUserId);
    const fromFriendRef = fromUserRef.collection("friends").doc(toUserId);
    const toFriendRef = toUserRef.collection("friends").doc(fromUserId);

    const [fromFriendSnap, toFriendSnap] = await tx.getAll(fromFriendRef, toFriendRef);

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    if (!fromFriendSnap.exists || !toFriendSnap.exists) {
      tx.set(fromFriendRef, {
        userId: toUserId,
        name: toUserName,
        photoUrl: toUserPhotoUrl,
        createdAt: now,
      });

      tx.set(toFriendRef, {
        userId: fromUserId,
        name: fromUserName,
        photoUrl: fromUserPhotoUrl,
        createdAt: now,
      });
    }

    tx.update(requestRef, {
      status: "accepted",
      respondedAt: now,
    });
  });

  return { success: true };
});
