import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

interface CancelFriendRequestData {
  requestId: string;
}

function validate(data: CancelFriendRequestData): void {
  if (!data.requestId?.trim()) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
}

export const cancelFriendRequest = onCall<CancelFriendRequestData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { requestId } = request.data;
  validate(request.data);

  const uid = request.auth.uid;
  const requestRef = db.collection("friendRequests").doc(requestId);
  const requestSnap = await requestRef.get();

  if (!requestSnap.exists) {
    throw new HttpsError("not-found", "Friend request not found.");
  }

  const req = requestSnap.data()!;

  if (req.fromUserId !== uid) {
    throw new HttpsError("permission-denied", "You cannot cancel this request.");
  }

  if (req.status === "cancelled") {
    return { success: true };
  }

  if (req.status !== "pending") {
    throw new HttpsError("failed-precondition", "This request can no longer be cancelled.");
  }

  await requestRef.update({
    status: "cancelled",
    cancelledAt: Timestamp.now(),
  });

  return { success: true };
});
