import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
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

  // Use the existing (fromUserId, status) and (toUserId, status) composite
  // indexes and filter the counterpart user in code, avoiding a 3-field index.
  const [targetSnap, friendSnap, senderSnap, outboundPendingSnap, inboundPendingSnap] =
    await Promise.all([
      db.collection("users").doc(toUserId).get(),
      db.collection("users").doc(uid).collection("friends").doc(toUserId).get(),
      db.collection("users").doc(uid).get(),
      db.collection("friendRequests")
        .where("fromUserId", "==", uid)
        .where("status", "==", "pending")
        .get(),
      db.collection("friendRequests")
        .where("toUserId", "==", uid)
        .where("status", "==", "pending")
        .get(),
    ]).catch((err) => {
      logger.error("sendFriendRequest: Firestore read failed", { error: String(err), uid, toUserId });
      throw err;
    });

  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  if (friendSnap.exists) {
    throw new HttpsError("already-exists", "You are already friends with this user.");
  }

  const hasOutbound = outboundPendingSnap.docs.some((d) => d.data().toUserId === toUserId);
  const hasInbound = inboundPendingSnap.docs.some((d) => d.data().fromUserId === toUserId);
  if (hasOutbound || hasInbound) {
    throw new HttpsError("already-exists", "A pending friend request already exists.");
  }

  if (!senderSnap.exists) {
    throw new HttpsError("failed-precondition", "Your profile is not set up yet.");
  }

  const senderData = senderSnap.data()!;
  const targetData = targetSnap.data()!;

  const fromUserName = typeof senderData.name === "string" ? senderData.name : "";
  const toUserName = typeof targetData.name === "string" ? targetData.name : "";

  if (!fromUserName) {
    throw new HttpsError("failed-precondition", "Your profile is missing a name.");
  }
  if (!toUserName) {
    throw new HttpsError("failed-precondition", "That user's profile is incomplete.");
  }

  const fromUserPhotoUrl = typeof senderData.photoUrl === "string" ? senderData.photoUrl : null;
  const toUserPhotoUrl = typeof targetData.photoUrl === "string" ? targetData.photoUrl : null;

  await db.collection("friendRequests").add({
    fromUserId: uid,
    toUserId,
    // Snapshot fields — eliminates N+1 reads on the read path.
    fromUserName,
    fromUserPhotoUrl,
    toUserName,
    toUserPhotoUrl,
    status: "pending",
    createdAt: Timestamp.now(),
  });
});
