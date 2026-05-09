import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface GetIncomingFriendRequestsData {
  limit?: number;
}

interface IncomingRequestSummary {
  requestId: string;
  fromUserId: string;
  createdAt: string;
}

interface GetIncomingFriendRequestsResult {
  requests: IncomingRequestSummary[];
}

// ─── Safe field helpers ───────────────────────────────────────────────────────

function safeTimestampToISO(value: unknown, fieldName: string, docId: string): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string" && value.length > 0) {
    console.warn(`getIncomingFriendRequests: doc ${docId} field "${fieldName}" is a string, expected Timestamp — value: ${value}`);
    return value;
  }
  console.error(`getIncomingFriendRequests: doc ${docId} field "${fieldName}" is invalid:`, value);
  throw new HttpsError("internal", `Document ${docId} has an invalid "${fieldName}" field (type: ${typeof value}).`);
}

// ─── Callable function ────────────────────────────────────────────────────────

export const getIncomingFriendRequests = onCall<GetIncomingFriendRequestsData>(async (request) => {
  console.log("getIncomingFriendRequests called");
  console.log("  auth uid :", request.auth?.uid ?? "(none)");

  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const uid = request.auth.uid;
    const { limit } = request.data;

    let query = db
      .collection("friendRequests")
      .where("toUserId", "==", uid)
      .where("status", "==", "pending")
      .orderBy("createdAt", "desc");

    if (limit !== undefined) {
      query = query.limit(limit);
    }

    const snap = await query.get();
    console.log("Query result size:", snap.size);

    const requests: IncomingRequestSummary[] = snap.docs.flatMap((doc) => {
      const d = doc.data();
      if (!d.fromUserId || !d.createdAt) {
        console.warn(`getIncomingFriendRequests: doc ${doc.id} missing required fields — skipping`);
        return [];
      }
      return [{
        requestId: doc.id,
        fromUserId: d.fromUserId as string,
        createdAt: safeTimestampToISO(d.createdAt, "createdAt", doc.id),
      }];
    });

    console.log(`getIncomingFriendRequests OK — returning ${requests.length} requests`);

    return { requests } satisfies GetIncomingFriendRequestsResult;

  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error instanceof Error ? error.message : String(error);
    console.error("getIncomingFriendRequests UNHANDLED ERROR:", error);
    throw new HttpsError("internal", message);
  }
});
