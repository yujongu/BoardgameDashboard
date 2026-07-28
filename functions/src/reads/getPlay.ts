import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../shared/db";
import { assertParticipant } from "../shared/auth";
import { ParticipantDocument, PlayDocument } from "../shared/types";

// ─── Input / output types ─────────────────────────────────────────────────────

interface GetPlayData {
  playId: string;
}

interface ParticipantResult {
  userId: string | null;
  name: string;
  photoUrl?: string;
  isWinner: boolean;
  score?: number;
  rank?: number;
  teamId?: string;
}

interface GetPlayResult {
  playId: string;
  gameId: string;
  gameName: string;
  playedAt: string;
  createdBy: string;
  participantCount: number;
  location?: string;
  notes?: string;
  participants: ParticipantResult[];
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validate(data: GetPlayData): void {
  if (!data.playId?.trim()) {
    throw new HttpsError("invalid-argument", "playId is required.");
  }
}

// ─── Callable function ────────────────────────────────────────────────────────

export const getPlay = onCall<GetPlayData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data;
  validate(data);

  const playRef = db.collection("plays").doc(data.playId);

  // Fetch play document and participants subcollection in parallel — 2 reads total.
  const [playSnap, participantsSnap] = await Promise.all([
    playRef.get(),
    playRef.collection("participants").get(),
  ]);

  if (!playSnap.exists) {
    throw new HttpsError("not-found", `Play ${data.playId} does not exist.`);
  }

  const play = playSnap.data() as PlayDocument;
  assertParticipant(play, request.auth.uid);

  const participants: ParticipantResult[] = participantsSnap.docs.map((doc) => {
    const p = doc.data() as ParticipantDocument;
    return {
      userId: p.userId,
      name: p.name,
      isWinner: p.isWinner,
      ...(p.photoUrl !== undefined && { photoUrl: p.photoUrl }),
      ...(p.score !== undefined && { score: p.score }),
      ...(p.rank !== undefined && { rank: p.rank }),
      ...(p.teamId !== undefined && { teamId: p.teamId }),
    };
  });

  return {
    playId: playSnap.id,
    gameId: play.gameId,
    gameName: play.gameName,
    playedAt: (play.playedAt as Timestamp).toDate().toISOString(),
    createdBy: play.createdBy,
    participantCount: play.participantCount,
    ...(play.location !== undefined && { location: play.location }),
    ...(play.notes !== undefined && { notes: play.notes }),
    participants,
  } satisfies GetPlayResult;
});
