import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface GetOutgoingFriendRequestsData {
  limit?: number;
}

interface OutgoingRequestSummary {
  requestId: string;
  toUserId: string;
  toUserName: string;
  toUserPhotoUrl: string | null;
  createdAt: string;
}

interface GetOutgoingFriendRequestsResult {
  requests: OutgoingRequestSummary[];
}

// ─── Safe field helpers ───────────────────────────────────────────────────────

function safeTimestampToISO(value: unknown, fieldName: string, docId: string): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string" && value.length > 0) {
    console.warn(`getOutgoingFriendRequests: doc ${docId} field "${fieldName}" is a string, expected Timestamp — value: ${value}`);
    return value;
  }
  console.error(`getOutgoingFriendRequests: doc ${docId} field "${fieldName}" is invalid:`, value);
  throw new HttpsError("internal", `Document ${docId} has an invalid "${fieldName}" field (type: ${typeof value}).`);
}

// ─── Callable function ────────────────────────────────────────────────────────

export const getOutgoingFriendRequests = onCall<GetOutgoingFriendRequestsData>(async (request) => {
  console.log("getOutgoingFriendRequests called");
  console.log("  auth uid :", request.auth?.uid ?? "(none)");

  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const uid = request.auth.uid;
    const { limit } = request.data;

    let query = db
      .collection("friendRequests")
      .where("fromUserId", "==", uid)
      .where("status", "==", "pending")
      .orderBy("createdAt", "desc");

    if (limit !== undefined) {
      query = query.limit(limit);
    }

    const snap = await query.get();
    console.log("Query result size:", snap.size);

    const requests: OutgoingRequestSummary[] = snap.docs.flatMap((doc) => {
      const d = doc.data();
      if (!d.toUserId || !d.createdAt) {
        console.warn(`getOutgoingFriendRequests: doc ${doc.id} missing required fields — skipping`);
        return [];
      }
      let toUserName: string;
      let toUserPhotoUrl: string | null;
      if (typeof d.toUserName === "string") {
        toUserName = d.toUserName;
        toUserPhotoUrl = typeof d.toUserPhotoUrl === "string" ? d.toUserPhotoUrl : null;
      } else {
        console.warn(`getOutgoingFriendRequests: doc ${doc.id} missing snapshot fields — no legacy recipient name available`);
        toUserName = "Unknown user";
        toUserPhotoUrl = null;
      }
      return [{
        requestId: doc.id,
        toUserId: d.toUserId as string,
        toUserName,
        toUserPhotoUrl,
        createdAt: safeTimestampToISO(d.createdAt, "createdAt", doc.id),
      }];
    });

    console.log(`getOutgoingFriendRequests OK — returning ${requests.length} requests`);

    return { requests } satisfies GetOutgoingFriendRequestsResult;

  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error instanceof Error ? error.message : String(error);
    console.error("getOutgoingFriendRequests UNHANDLED ERROR:", error);
    throw new HttpsError("internal", message);
  }
});
