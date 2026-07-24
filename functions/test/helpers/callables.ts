/**
 * Thin wrappers around each onCall function.
 *
 * Firebase Functions v5 attaches `.run(data, context)` directly to the exported
 * HttpsFunction.  Calling it bypasses the HTTP layer and invokes the handler
 * with a synthesised CallableRequest — identical to how firebase-functions-test
 * wraps callables, but without the extra dependency.
 *
 * `context.auth` must be provided to pass the auth guard; omit it (or pass {})
 * to test the unauthenticated error branch.
 */

import { createPlay }    from "../../src/plays/createPlay";
import { updatePlay }    from "../../src/plays/updatePlay";
import { deletePlay }    from "../../src/plays/deletePlay";
import { listMyPlays }   from "../../src/reads/listMyPlays";
import { getPlay }       from "../../src/reads/getPlay";
import { getMyLibrary }  from "../../src/reads/getMyLibrary";
import { listBoardGames } from "../../src/library/listBoardGames";
import { sendFriendRequest }        from "../../src/friends/sendFriendRequest";
import { acceptFriendRequest }      from "../../src/friends/acceptFriendRequest";
import { rejectFriendRequest }      from "../../src/friends/rejectFriendRequest";
import { cancelFriendRequest }      from "../../src/friends/cancelFriendRequest";
import { removeFriend }             from "../../src/friends/removeFriend";
import { getMyFriends }             from "../../src/friends/getMyFriends";
import { getIncomingFriendRequests } from "../../src/friends/getIncomingFriendRequests";
import { getOutgoingFriendRequests } from "../../src/friends/getOutgoingFriendRequests";

// ─── Types ────────────────────────────────────────────────────────────────────

// firebase-functions v5 assigns func.run = withInit(handler) where handler is
// (req: CallableRequest<T>) => Return.  withInit spreads all arguments through
// unchanged, so .run must be called with a single CallableRequest object — NOT
// the legacy (data, context) two-argument form used by firebase-functions-test.
interface CallableRequest {
  data: unknown;
  auth?: { uid: string; token: Record<string, unknown> };
  rawRequest: Record<string, never>;
}

type AnyCallable = {
  run: (req: CallableRequest) => Promise<unknown>;
};

/** Returns a mock auth object for the given uid.  Export allows tests to
 *  inspect or extend the auth payload when needed. */
export function mockAuth(uid: string): { uid: string; token: { uid: string } } {
  return { uid, token: { uid } };
}

function makeReq(data: unknown, uid: string): CallableRequest {
  return { data, auth: mockAuth(uid), rawRequest: {} };
}

function makeReqNoAuth(data: unknown): CallableRequest {
  return { data, rawRequest: {} };
}

// ─── Wrapped callables ────────────────────────────────────────────────────────

export interface ParticipantInput {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
}

export interface CreatePlayInput {
  gameId: string;
  gameName: string;
  playedAt: string;
  participants: ParticipantInput[];
  location?: string;
  notes?: string;
}

export interface UpdatePlayInput extends CreatePlayInput {
  playId: string;
}

// ─── Authenticated callables ──────────────────────────────────────────────────

export const callCreatePlay = (data: CreatePlayInput, uid: string) =>
  (createPlay as unknown as AnyCallable).run(makeReq(data, uid)) as Promise<{
    playId: string;
  }>;

export const callUpdatePlay = (data: UpdatePlayInput, uid: string) =>
  (updatePlay as unknown as AnyCallable).run(makeReq(data, uid)) as Promise<{
    success: true;
  }>;

export const callDeletePlay = (playId: string, uid: string) =>
  (deletePlay as unknown as AnyCallable).run(makeReq({ playId }, uid)) as Promise<{
    success: true;
  }>;

export const callListMyPlays = (
  data: { limit?: number; cursor?: string },
  uid: string
) =>
  (listMyPlays as unknown as AnyCallable).run(makeReq(data, uid)) as Promise<{
    plays: Array<{
      playId: string;
      gameId: string;
      gameName: string;
      playedAt: string;
      participantCount: number;
    }>;
    nextCursor: string | null;
  }>;

export const callGetPlay = (playId: string, uid: string) =>
  (getPlay as unknown as AnyCallable).run(makeReq({ playId }, uid)) as Promise<{
    playId: string;
    gameId: string;
    gameName: string;
    playedAt: string;
    createdBy: string;
    participantCount: number;
    participants: ParticipantInput[];
  }>;

export const callGetMyLibrary = (uid: string) =>
  (getMyLibrary as unknown as AnyCallable).run(makeReq({}, uid)) as Promise<{
    library: Array<{
      gameId: string;
      gameName: string;
      playCount: number;
      winCount: number;
      lastPlayedAt: string | null;
    }>;
  }>;

// ─── Friend callables ─────────────────────────────────────────────────────────

export const callSendFriendRequest = (toUserId: string, uid: string) =>
  (sendFriendRequest as unknown as AnyCallable).run(makeReq({ toUserId }, uid));

export const callAcceptFriendRequest = (requestId: string, uid: string) =>
  (acceptFriendRequest as unknown as AnyCallable).run(
    makeReq({ requestId }, uid)
  ) as Promise<{ success: true }>;

export const callRejectFriendRequest = (requestId: string, uid: string) =>
  (rejectFriendRequest as unknown as AnyCallable).run(
    makeReq({ requestId }, uid)
  ) as Promise<{ success: true }>;

export const callCancelFriendRequest = (requestId: string, uid: string) =>
  (cancelFriendRequest as unknown as AnyCallable).run(
    makeReq({ requestId }, uid)
  ) as Promise<{ success: true }>;

export const callRemoveFriend = (friendId: string, uid: string) =>
  (removeFriend as unknown as AnyCallable).run(
    makeReq({ friendId }, uid)
  ) as Promise<{ success: true }>;

export const callGetMyFriends = (uid: string, limit?: number) =>
  (getMyFriends as unknown as AnyCallable).run(
    makeReq(limit !== undefined ? { limit } : {}, uid)
  ) as Promise<{
    friends: Array<{
      userId: string;
      name: string;
      photoUrl: string | null;
      createdAt: string;
    }>;
  }>;

export const callGetIncomingFriendRequests = (uid: string, limit?: number) =>
  (getIncomingFriendRequests as unknown as AnyCallable).run(
    makeReq(limit !== undefined ? { limit } : {}, uid)
  ) as Promise<{
    requests: Array<{
      requestId: string;
      fromUserId: string;
      fromUserName: string;
      fromUserPhotoUrl: string | null;
      createdAt: string;
    }>;
  }>;

export const callGetOutgoingFriendRequests = (uid: string, limit?: number) =>
  (getOutgoingFriendRequests as unknown as AnyCallable).run(
    makeReq(limit !== undefined ? { limit } : {}, uid)
  ) as Promise<{
    requests: Array<{
      requestId: string;
      toUserId: string;
      toUserName: string;
      toUserPhotoUrl: string | null;
      createdAt: string;
    }>;
  }>;

export const callListBoardGames = (
  data: { search?: string; limit?: number },
  uid: string,
) =>
  (listBoardGames as unknown as AnyCallable).run(makeReq(data, uid)) as Promise<{
    games: Array<{ gameId: string; name: string }>;
  }>;

export const callListBoardGamesNoAuth = (data: {
  search?: string;
  limit?: number;
}) => (listBoardGames as unknown as AnyCallable).run(makeReqNoAuth(data));

// ─── No-auth variants (for validation tests) ──────────────────────────────────

export const callCreatePlayNoAuth = (data: CreatePlayInput) =>
  (createPlay as unknown as AnyCallable).run(makeReqNoAuth(data));

export const callDeletePlayNoAuth = (playId: string) =>
  (deletePlay as unknown as AnyCallable).run(makeReqNoAuth({ playId }));

export const callGetMyLibraryNoAuth = () =>
  (getMyLibrary as unknown as AnyCallable).run(makeReqNoAuth({}));

export const callSendFriendRequestNoAuth = (toUserId: string) =>
  (sendFriendRequest as unknown as AnyCallable).run(makeReqNoAuth({ toUserId }));

export const callGetMyFriendsNoAuth = () =>
  (getMyFriends as unknown as AnyCallable).run(makeReqNoAuth({}));
