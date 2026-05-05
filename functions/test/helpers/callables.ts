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

// ─── No-auth variants (for validation tests) ──────────────────────────────────

export const callCreatePlayNoAuth = (data: CreatePlayInput) =>
  (createPlay as unknown as AnyCallable).run(makeReqNoAuth(data));

export const callDeletePlayNoAuth = (playId: string) =>
  (deletePlay as unknown as AnyCallable).run(makeReqNoAuth({ playId }));

export const callGetMyLibraryNoAuth = () =>
  (getMyLibrary as unknown as AnyCallable).run(makeReqNoAuth({}));
