/**
 * Friend-feature tests: sendFriendRequest, acceptFriendRequest,
 * rejectFriendRequest, cancelFriendRequest, removeFriend, getMyFriends,
 * getIncomingFriendRequests, getOutgoingFriendRequests.
 *
 * Runs against the Firestore Emulator with three seeded dummy accounts
 * (alice, bob, carol). Requires `firebase emulators:start --only firestore`.
 */

import { clearDb, db } from "./setup";
import { seedUser } from "./helpers/seed";
import {
  callSendFriendRequest,
  callAcceptFriendRequest,
  callRejectFriendRequest,
  callCancelFriendRequest,
  callRemoveFriend,
  callGetMyFriends,
  callGetIncomingFriendRequests,
  callGetOutgoingFriendRequests,
  callSendFriendRequestNoAuth,
  callGetMyFriendsNoAuth,
} from "./helpers/callables";

const ALICE = "test-alice";
const BOB = "test-bob";
const CAROL = "test-carol";

async function seedDummyAccounts(): Promise<void> {
  await Promise.all([
    seedUser(ALICE, { name: "Alice Test", photoUrl: "https://example.com/a.png" }),
    seedUser(BOB, { name: "Bob Test" }),
    seedUser(CAROL, { name: "Carol Test" }),
  ]);
}

/** Returns the single friendRequest doc between the two users, or null. */
async function getRequestDoc(fromUserId: string, toUserId: string) {
  const snap = await db
    .collection("friendRequests")
    .where("fromUserId", "==", fromUserId)
    .get();
  const doc = snap.docs.find((d) => d.data().toUserId === toUserId);
  return doc ? { id: doc.id, ...doc.data() } : null;
}

async function getFriendDoc(ownerUid: string, friendUid: string) {
  const snap = await db
    .collection("users")
    .doc(ownerUid)
    .collection("friends")
    .doc(friendUid)
    .get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

/** Sends a request and returns its document id. */
async function sendRequest(fromUid: string, toUid: string): Promise<string> {
  await callSendFriendRequest(toUid, fromUid);
  const doc = await getRequestDoc(fromUid, toUid);
  if (!doc) throw new Error("request doc not found after sendFriendRequest");
  return doc.id;
}

beforeEach(async () => {
  await clearDb();
  await seedDummyAccounts();
});

// ─── sendFriendRequest ────────────────────────────────────────────────────────

describe("sendFriendRequest", () => {
  it("creates a pending request with snapshot fields", async () => {
    await callSendFriendRequest(BOB, ALICE);

    const doc = await getRequestDoc(ALICE, BOB);
    expect(doc).toMatchObject({
      fromUserId: ALICE,
      toUserId: BOB,
      fromUserName: "Alice Test",
      fromUserPhotoUrl: "https://example.com/a.png",
      toUserName: "Bob Test",
      toUserPhotoUrl: null,
      status: "pending",
    });
  });

  it("rejects unauthenticated calls", async () => {
    await expect(callSendFriendRequestNoAuth(BOB)).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("rejects an empty toUserId", async () => {
    await expect(callSendFriendRequest("  ", ALICE)).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("rejects sending a request to yourself", async () => {
    await expect(callSendFriendRequest(ALICE, ALICE)).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("rejects when the target user does not exist", async () => {
    await expect(
      callSendFriendRequest("no-such-user", ALICE)
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects when the sender has no profile", async () => {
    await expect(
      callSendFriendRequest(BOB, "unregistered-user")
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects a duplicate pending request in the same direction", async () => {
    await callSendFriendRequest(BOB, ALICE);
    await expect(callSendFriendRequest(BOB, ALICE)).rejects.toMatchObject({
      code: "already-exists",
    });
  });

  it("rejects a pending request in the opposite direction", async () => {
    await callSendFriendRequest(BOB, ALICE);
    await expect(callSendFriendRequest(ALICE, BOB)).rejects.toMatchObject({
      code: "already-exists",
    });
  });

  it("rejects when the two users are already friends", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);

    await expect(callSendFriendRequest(BOB, ALICE)).rejects.toMatchObject({
      code: "already-exists",
    });
  });

  it("allows a new request after a previous one was rejected", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callRejectFriendRequest(requestId, BOB);

    await expect(callSendFriendRequest(BOB, ALICE)).resolves.toBeUndefined();
  });
});

// ─── acceptFriendRequest ──────────────────────────────────────────────────────

describe("acceptFriendRequest", () => {
  it("creates symmetric friend docs and marks the request accepted", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callAcceptFriendRequest(requestId, BOB)).resolves.toEqual({
      success: true,
    });

    const aliceSide = await getFriendDoc(ALICE, BOB);
    const bobSide = await getFriendDoc(BOB, ALICE);
    expect(aliceSide).toMatchObject({ userId: BOB, name: "Bob Test", photoUrl: null });
    expect(bobSide).toMatchObject({
      userId: ALICE,
      name: "Alice Test",
      photoUrl: "https://example.com/a.png",
    });

    const requestDoc = await getRequestDoc(ALICE, BOB);
    expect(requestDoc).toMatchObject({ status: "accepted" });
  });

  it("is idempotent when the request is already accepted", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);
    await expect(callAcceptFriendRequest(requestId, BOB)).resolves.toEqual({
      success: true,
    });
  });

  it("rejects acceptance by anyone other than the recipient", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callAcceptFriendRequest(requestId, CAROL)).rejects.toMatchObject({
      code: "permission-denied",
    });
    // The sender cannot accept their own request either.
    await expect(callAcceptFriendRequest(requestId, ALICE)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("rejects a nonexistent request id", async () => {
    await expect(callAcceptFriendRequest("nope", BOB)).rejects.toMatchObject({
      code: "not-found",
    });
  });

  it("rejects accepting a request that was already rejected", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callRejectFriendRequest(requestId, BOB);
    await expect(callAcceptFriendRequest(requestId, BOB)).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });

  it("rejects accepting a request that was cancelled by the sender", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callCancelFriendRequest(requestId, ALICE);
    await expect(callAcceptFriendRequest(requestId, BOB)).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });
});

// ─── rejectFriendRequest ──────────────────────────────────────────────────────

describe("rejectFriendRequest", () => {
  it("marks the request rejected and creates no friendship", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callRejectFriendRequest(requestId, BOB)).resolves.toEqual({
      success: true,
    });

    const requestDoc = await getRequestDoc(ALICE, BOB);
    expect(requestDoc).toMatchObject({ status: "rejected" });
    expect(await getFriendDoc(ALICE, BOB)).toBeNull();
    expect(await getFriendDoc(BOB, ALICE)).toBeNull();
  });

  it("is idempotent when the request is already rejected", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callRejectFriendRequest(requestId, BOB);
    await expect(callRejectFriendRequest(requestId, BOB)).resolves.toEqual({
      success: true,
    });
  });

  it("rejects rejection by anyone other than the recipient", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callRejectFriendRequest(requestId, ALICE)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("fails when the request was already accepted", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);
    await expect(callRejectFriendRequest(requestId, BOB)).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });
});

// ─── cancelFriendRequest ──────────────────────────────────────────────────────

describe("cancelFriendRequest", () => {
  it("lets the sender cancel a pending request", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callCancelFriendRequest(requestId, ALICE)).resolves.toEqual({
      success: true,
    });

    const requestDoc = await getRequestDoc(ALICE, BOB);
    expect(requestDoc).toMatchObject({ status: "cancelled" });
  });

  it("is idempotent when the request is already cancelled", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callCancelFriendRequest(requestId, ALICE);
    await expect(callCancelFriendRequest(requestId, ALICE)).resolves.toEqual({
      success: true,
    });
  });

  it("rejects cancellation by anyone other than the sender", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await expect(callCancelFriendRequest(requestId, BOB)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("fails when the request was already accepted", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);
    await expect(callCancelFriendRequest(requestId, ALICE)).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });
});

// ─── getMyFriends ─────────────────────────────────────────────────────────────

describe("getMyFriends", () => {
  it("rejects unauthenticated calls", async () => {
    await expect(callGetMyFriendsNoAuth()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("returns an empty list for a user with no friends", async () => {
    const result = await callGetMyFriends(ALICE);
    expect(result.friends).toEqual([]);
  });

  it("returns accepted friends for both sides", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);

    const aliceFriends = await callGetMyFriends(ALICE);
    expect(aliceFriends.friends).toHaveLength(1);
    expect(aliceFriends.friends[0]).toMatchObject({
      userId: BOB,
      name: "Bob Test",
      photoUrl: null,
    });
    expect(typeof aliceFriends.friends[0].createdAt).toBe("string");

    const bobFriends = await callGetMyFriends(BOB);
    expect(bobFriends.friends).toHaveLength(1);
    expect(bobFriends.friends[0]).toMatchObject({
      userId: ALICE,
      name: "Alice Test",
      photoUrl: "https://example.com/a.png",
    });
  });

  it("respects the limit parameter", async () => {
    const reqFromBob = await sendRequest(BOB, ALICE);
    await callAcceptFriendRequest(reqFromBob, ALICE);
    const reqFromCarol = await sendRequest(CAROL, ALICE);
    await callAcceptFriendRequest(reqFromCarol, ALICE);

    const all = await callGetMyFriends(ALICE);
    expect(all.friends).toHaveLength(2);

    const limited = await callGetMyFriends(ALICE, 1);
    expect(limited.friends).toHaveLength(1);
  });
});

// ─── getIncoming / getOutgoing friend requests ────────────────────────────────

describe("incoming and outgoing request lists", () => {
  it("shows a pending request in the recipient's incoming and sender's outgoing lists", async () => {
    const requestId = await sendRequest(ALICE, BOB);

    const bobIncoming = await callGetIncomingFriendRequests(BOB);
    expect(bobIncoming.requests).toHaveLength(1);
    expect(bobIncoming.requests[0]).toMatchObject({
      requestId,
      fromUserId: ALICE,
      fromUserName: "Alice Test",
      fromUserPhotoUrl: "https://example.com/a.png",
    });

    const aliceOutgoing = await callGetOutgoingFriendRequests(ALICE);
    expect(aliceOutgoing.requests).toHaveLength(1);
    expect(aliceOutgoing.requests[0]).toMatchObject({
      requestId,
      toUserId: BOB,
      toUserName: "Bob Test",
      toUserPhotoUrl: null,
    });

    // No cross-contamination with an unrelated user.
    const carolIncoming = await callGetIncomingFriendRequests(CAROL);
    expect(carolIncoming.requests).toEqual([]);
  });

  it("removes the request from both lists once accepted", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);

    expect((await callGetIncomingFriendRequests(BOB)).requests).toEqual([]);
    expect((await callGetOutgoingFriendRequests(ALICE)).requests).toEqual([]);
  });

  it("removes the request from both lists once rejected", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callRejectFriendRequest(requestId, BOB);

    expect((await callGetIncomingFriendRequests(BOB)).requests).toEqual([]);
    expect((await callGetOutgoingFriendRequests(ALICE)).requests).toEqual([]);
  });

  it("removes the request from both lists once cancelled", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callCancelFriendRequest(requestId, ALICE);

    expect((await callGetIncomingFriendRequests(BOB)).requests).toEqual([]);
    expect((await callGetOutgoingFriendRequests(ALICE)).requests).toEqual([]);
  });
});

// ─── removeFriend ─────────────────────────────────────────────────────────────

describe("removeFriend", () => {
  it("removes both sides of the friendship and the request history", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);

    await expect(callRemoveFriend(BOB, ALICE)).resolves.toEqual({ success: true });

    expect(await getFriendDoc(ALICE, BOB)).toBeNull();
    expect(await getFriendDoc(BOB, ALICE)).toBeNull();
    expect(await getRequestDoc(ALICE, BOB)).toBeNull();
    expect((await callGetMyFriends(ALICE)).friends).toEqual([]);
    expect((await callGetMyFriends(BOB)).friends).toEqual([]);
  });

  it("is idempotent when the users are not friends", async () => {
    await expect(callRemoveFriend(BOB, ALICE)).resolves.toEqual({ success: true });
  });

  it("does not touch friendships with other users", async () => {
    const reqBob = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(reqBob, BOB);
    const reqCarol = await sendRequest(ALICE, CAROL);
    await callAcceptFriendRequest(reqCarol, CAROL);

    await callRemoveFriend(BOB, ALICE);

    const aliceFriends = await callGetMyFriends(ALICE);
    expect(aliceFriends.friends).toHaveLength(1);
    expect(aliceFriends.friends[0].userId).toBe(CAROL);
  });

  it("allows re-friending after removal", async () => {
    const requestId = await sendRequest(ALICE, BOB);
    await callAcceptFriendRequest(requestId, BOB);
    await callRemoveFriend(BOB, ALICE);

    // Full second cycle: send → accept → both sides friends again.
    const secondRequestId = await sendRequest(BOB, ALICE);
    await callAcceptFriendRequest(secondRequestId, ALICE);

    expect((await callGetMyFriends(ALICE)).friends).toHaveLength(1);
    expect((await callGetMyFriends(BOB)).friends).toHaveLength(1);
  });
});
