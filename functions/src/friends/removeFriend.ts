import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "../shared/db";

interface RemoveFriendData {
  friendId: string;
}

function validate(data: RemoveFriendData): void {
  if (!data.friendId?.trim()) {
    throw new HttpsError("invalid-argument", "friendId is required.");
  }
}

export const removeFriend = onCall<RemoveFriendData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { friendId } = request.data;
  validate(request.data);

  const uid = request.auth.uid;

  const friendshipSnap = await db
    .collection("users").doc(uid)
    .collection("friends").doc(friendId)
    .get();

  // Already not friends — idempotent success.
  if (!friendshipSnap.exists) {
    return { success: true };
  }

  // Find all friendRequest documents between these two users in either direction.
  // Queries use the auto-indexed fromUserId field; toUserId is filtered in code
  // to avoid requiring a new composite index.
  const [outboundSnap, inboundSnap] = await Promise.all([
    db.collection("friendRequests").where("fromUserId", "==", uid).get(),
    db.collection("friendRequests").where("fromUserId", "==", friendId).get(),
  ]);

  const requestDocsToDelete = [
    ...outboundSnap.docs.filter((d) => d.data().toUserId === friendId),
    ...inboundSnap.docs.filter((d) => d.data().toUserId === uid),
  ];

  await db.runTransaction(async (tx) => {
    // Remove both sides of the friendship.
    tx.delete(db.collection("users").doc(uid).collection("friends").doc(friendId));
    tx.delete(db.collection("users").doc(friendId).collection("friends").doc(uid));

    // Remove all friend request history between the two users (accepted, rejected,
    // cancelled — every status) so no stale documents are left behind.
    for (const doc of requestDocsToDelete) {
      tx.delete(doc.ref);
    }
  });

  return { success: true };
});
