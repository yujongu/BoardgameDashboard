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

  const now = Timestamp.now();

  // ── Transaction: user/friend reads, then writes ───────────────────────────

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ ─────────────────────────────────────────────────────────

    const fromUserRef = db.collection("users").doc(fromUserId);
    const toUserRef = db.collection("users").doc(toUserId);
    const fromFriendRef = fromUserRef.collection("friends").doc(toUserId);
    const toFriendRef = toUserRef.collection("friends").doc(fromUserId);

    // Order: fromUser, toUser, fromFriend, toFriend
    const [fromUserSnap, toUserSnap, fromFriendSnap, toFriendSnap] = await tx.getAll(
      fromUserRef,
      toUserRef,
      fromFriendRef,
      toFriendRef
    );

    if (!fromUserSnap.exists || !toUserSnap.exists) {
      throw new HttpsError("not-found", "One or more users not found.");
    }

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    if (!fromFriendSnap.exists || !toFriendSnap.exists) {
      const fromUser = fromUserSnap.data()!;
      const toUser = toUserSnap.data()!;

      tx.set(fromFriendRef, {
        userId: toUserId,
        name: toUser.name,
        photoUrl: toUser.photoUrl ?? null,
        createdAt: now,
      });

      tx.set(toFriendRef, {
        userId: fromUserId,
        name: fromUser.name,
        photoUrl: fromUser.photoUrl ?? null,
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
