import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";
import { assertNoDuplicateParticipants } from "../shared/auth";
import {
  gameStatsRef,
  incrementCoopPlays,
  incrementGameStats,
  incrementStats,
  statsRef,
  upsertUserLibrary,
  userLibraryRef,
} from "../shared/helpers";

// ─── Input / output types ─────────────────────────────────────────────────────

interface ParticipantInput {
  userId: string | null;
  name: string;
  isWinner: boolean;
  score?: number;
}

type PlayMode = "competitive" | "coop";

interface CreatePlayData {
  gameId: string;
  gameName: string;
  /** ISO 8601 string — converted to Firestore Timestamp server-side. */
  playedAt: string;
  participants: ParticipantInput[];
  location?: string;
  notes?: string;
  // Cooperative fields — present only when mode === "coop".
  mode?: PlayMode;
  outcome?: "win" | "loss";
  campaignId?: string;
  stageId?: string;
  difficulty?: string;
  teamScore?: number;
}

interface CreatePlayResult {
  playId: string;
}

/** Narrowed type used in Phase 1 and the write loop. */
type RegisteredParticipant = ParticipantInput & { userId: string };

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: CreatePlayData): void {
  if (!data.gameId?.trim()) {
    throw new HttpsError("invalid-argument", "gameId is required.");
  }
  if (!data.gameName?.trim()) {
    throw new HttpsError("invalid-argument", "gameName is required.");
  }
  if (!data.playedAt || isNaN(Date.parse(data.playedAt))) {
    throw new HttpsError(
      "invalid-argument",
      "playedAt must be a valid ISO 8601 date string."
    );
  }
  if (!Array.isArray(data.participants) || data.participants.length === 0) {
    throw new HttpsError("invalid-argument", "participants must not be empty.");
  }
  for (const p of data.participants) {
    if (!p.name?.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Every participant must have a non-empty name."
      );
    }
  }
  assertNoDuplicateParticipants(data.participants);

  if (isCoop(data)) {
    if (data.outcome !== "win" && data.outcome !== "loss") {
      throw new HttpsError(
        "invalid-argument",
        "Cooperative plays require outcome 'win' or 'loss'."
      );
    }
    // campaignId and stageId travel together: a campaign advance needs both.
    if ((data.campaignId == null) !== (data.stageId == null)) {
      throw new HttpsError(
        "invalid-argument",
        "campaignId and stageId must be provided together."
      );
    }
  } else if (!data.participants.some((p) => p.isWinner)) {
    throw new HttpsError(
      "invalid-argument",
      "At least one participant must have isWinner = true."
    );
  }
}

function isCoop(data: CreatePlayData): boolean {
  return data.mode === "coop";
}

// ─── Callable function ────────────────────────────────────────────────────────

export const createPlay = onCall<CreatePlayData>({ minInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const { gameId, gameName, participants, location, notes } = data;
  const coop = isCoop(data);
  const createdBy = request.auth.uid;
  const playedAt = Timestamp.fromDate(new Date(data.playedAt));

  // Derive fields that are stable across transaction retries.
  const registered = participants.filter(
    (p): p is RegisteredParticipant => p.userId !== null
  );
  const participantIds = registered.map((p) => p.userId);

  // Allocate the ref outside the transaction so the ID is stable across retries.
  const playRef = db.collection("plays").doc();
  const campaignRef =
    coop && data.campaignId ? db.collection("campaigns").doc(data.campaignId) : null;

  await db.runTransaction(async (tx) => {
    // ── Phase 1: READ ─────────────────────────────────────────────────────────
    //
    // Competitive: userLibrary snapshots (first-play detection). Co-op skips
    // stats/library entirely, so it reads only the campaign doc (if advancing).

    let libSnapByUserId = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    if (!coop) {
      const libRefs = registered.map((p) => userLibraryRef(p.userId, gameId));
      const libSnaps = libRefs.length > 0 ? await tx.getAll(...libRefs) : [];
      libSnapByUserId = new Map(registered.map((p, i) => [p.userId, libSnaps[i]]));
    }

    let campaignCompleted = false;
    if (campaignRef) {
      const campaignSnap = await tx.get(campaignRef);
      if (!campaignSnap.exists) {
        throw new HttpsError("not-found", "Campaign not found.");
      }
      const memberIds = (campaignSnap.get("memberIds") as string[]) ?? [];
      if (!memberIds.includes(createdBy)) {
        throw new HttpsError(
          "permission-denied",
          "Only campaign members may log sessions."
        );
      }
      const stages = (campaignSnap.get("stages") as Record<string, { completed?: boolean }>) ?? {};
      campaignCompleted = stages[data.stageId!]?.completed === true;
    }

    // ── Phase 2: WRITE — no reads past this point ─────────────────────────────

    // 1. Play document.
    tx.set(playRef, {
      gameId,
      gameName,
      playedAt,
      createdBy,
      participantCount: participants.length,
      participantIds,
      ...(location && { location }),
      ...(notes && { notes }),
      ...(coop && {
        mode: "coop",
        outcome: data.outcome,
        ...(data.campaignId && { campaignId: data.campaignId }),
        ...(data.stageId && { stageId: data.stageId }),
        ...(data.difficulty && { difficulty: data.difficulty }),
        ...(data.teamScore !== undefined && { teamScore: data.teamScore }),
      }),
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Participants subcollection.
    for (const p of participants) {
      // 2a. Participant document. Co-op plays have no winner; force isWinner false.
      tx.set(playRef.collection("participants").doc(), {
        userId: p.userId,
        name: p.name,
        isWinner: coop ? false : p.isWinner,
        ...(!coop && p.score !== undefined && { score: p.score }),
        joinedAt: FieldValue.serverTimestamp(),
      });

      // Guests have no account to attribute anything to.
      if (p.userId === null) continue;

      // Co-op plays intentionally skip gameStats/library and every win figure.
      // Only the dedicated co-op counter is recorded, so Home can show a play
      // total that matches the session list without polluting the win rate.
      if (coop) {
        incrementCoopPlays(tx, statsRef(p.userId), playedAt);
        continue;
      }

      // 2b. Lifetime stats — write-only, FieldValue.increment creates on first call.
      incrementStats(tx, statsRef(p.userId), p.isWinner, playedAt);

      // 2c. Per-game stats — write-only, FieldValue.increment creates on first call.
      incrementGameStats(tx, gameStatsRef(p.userId, gameId), gameName, p.isWinner, playedAt);

      // 2d. User library — upsert using the snapshot fetched in Phase 1.
      upsertUserLibrary(
        tx,
        userLibraryRef(p.userId, gameId),
        libSnapByUserId.get(p.userId)!,
        gameName,
        p.isWinner,
        playedAt
      );
    }

    // 3. Advance the shared campaign stage (merge preserves other stages).
    //    `completed` latches true on a win and never downgrades on a later loss.
    if (campaignRef) {
      tx.set(
        campaignRef,
        {
          stages: {
            [data.stageId!]: {
              completed: campaignCompleted || data.outcome === "win",
              sessionCount: FieldValue.increment(1),
              lastOutcome: data.outcome,
              lastPlayedAt: playedAt,
            },
          },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  });

  return { playId: playRef.id } satisfies CreatePlayResult;
});
