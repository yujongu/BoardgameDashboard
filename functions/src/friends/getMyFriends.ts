import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";

// ─── Input / output types ─────────────────────────────────────────────────────

interface GetMyFriendsData {
  limit?: number;
}

interface FriendSummary {
  userId: string;
  name: string;
  photoUrl: string | null;
  createdAt: string;
}

interface GetMyFriendsResult {
  friends: FriendSummary[];
}

// ─── Safe field helpers ───────────────────────────────────────────────────────

function safeTimestampToISO(value: unknown, fieldName: string, docId: string): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string" && value.length > 0) {
    console.warn(`getMyFriends: doc ${docId} field "${fieldName}" is a string, expected Timestamp — value: ${value}`);
    return value;
  }
  console.error(`getMyFriends: doc ${docId} field "${fieldName}" is invalid:`, value);
  throw new HttpsError("internal", `Document ${docId} has an invalid "${fieldName}" field (type: ${typeof value}).`);
}

// ─── Callable function ────────────────────────────────────────────────────────

export const getMyFriends = onCall<GetMyFriendsData>(async (request) => {
  console.log("getMyFriends called");
  console.log("  auth uid :", request.auth?.uid ?? "(none)");

  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const uid = request.auth.uid;
    const { limit } = request.data;

    let query = db
      .collection("users")
      .doc(uid)
      .collection("friends")
      .orderBy("createdAt", "desc");

    if (limit !== undefined) {
      query = query.limit(limit);
    }

    const snap = await query.get();
    console.log("Query result size:", snap.size);

    const friends: FriendSummary[] = snap.docs.flatMap((doc) => {
      const d = doc.data();
      if (!d.userId || !d.name || !d.createdAt) {
        console.warn(`getMyFriends: doc ${doc.id} missing required fields — skipping`);
        return [];
      }
      return [{
        userId: d.userId as string,
        name: d.name as string,
        photoUrl: (d.photoUrl as string | null) ?? null,
        createdAt: safeTimestampToISO(d.createdAt, "createdAt", doc.id),
      }];
    });

    console.log(`getMyFriends OK — returning ${friends.length} friends`);

    return { friends } satisfies GetMyFriendsResult;

  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error instanceof Error ? error.message : String(error);
    console.error("getMyFriends UNHANDLED ERROR:", error);
    throw new HttpsError("internal", message);
  }
});
