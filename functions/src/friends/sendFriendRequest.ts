import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface SendFriendRequestData {
  toUserId: string;
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: SendFriendRequestData): void {
  if (!data.toUserId?.trim()) {
    throw new HttpsError("invalid-argument", "toUserId is required.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const sendFriendRequest = onCall<SendFriendRequestData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const uid = request.auth.uid;
  const { toUserId } = data;

  if (uid === toUserId) {
    throw new HttpsError("invalid-argument", "Cannot send a friend request to yourself.");
  }

  const [targetSnap, friendSnap, outboundSnap, inboundSnap, senderSnap] = await Promise.all([
    db.collection("users").doc(toUserId).get(),
    db.collection("users").doc(uid).collection("friends").doc(toUserId).get(),
    db.collection("friendRequests")
      .where("fromUserId", "==", uid)
      .where("toUserId", "==", toUserId)
      .where("status", "==", "pending")
      .limit(1)
      .get(),
    db.collection("friendRequests")
      .where("fromUserId", "==", toUserId)
      .where("toUserId", "==", uid)
      .where("status", "==", "pending")
      .limit(1)
      .get(),
    db.collection("users").doc(uid).get(),
  ]);

  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  if (friendSnap.exists) {
    throw new HttpsError("already-exists", "You are already friends with this user.");
  }

  if (!outboundSnap.empty || !inboundSnap.empty) {
    throw new HttpsError("already-exists", "A pending friend request already exists.");
  }

  const senderData = senderSnap.data() ?? {};

  await db.collection("friendRequests").add({
    fromUserId: uid,
    toUserId,
    fromName: senderData.name ?? "",
    ...(senderData.photoUrl ? { fromPhotoUrl: senderData.photoUrl } : {}),
    status: "pending",
    createdAt: Timestamp.now(),
  });
});
