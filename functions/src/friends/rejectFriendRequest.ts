import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface RejectFriendRequestData {
  requestId: string;
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: RejectFriendRequestData): void {
  if (!data.requestId?.trim()) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const rejectFriendRequest = onCall<RejectFriendRequestData>(async (request) => {
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
    throw new HttpsError("permission-denied", "You cannot reject this request.");
  }

  const fromUserId = req.fromUserId as string;
  const toUserId = req.toUserId as string;

  if (fromUserId === toUserId) {
    throw new HttpsError("invalid-argument", "Cannot reject a self-friend request.");
  }

  if (req.status === "rejected") {
    return { success: true };
  }

  if (req.status === "accepted") {
    throw new HttpsError("failed-precondition", "Friend request was already accepted.");
  }

  if (req.status !== "pending") {
    throw new HttpsError("failed-precondition", "Friend request is not in a pending state.");
  }

  const now = Timestamp.now();

  // ── Transaction: write only ───────────────────────────────────────────────

  await db.runTransaction(async (tx) => {
    tx.update(requestRef, {
      status: "rejected",
      respondedAt: now,
    });
  });

  return { success: true };
});
