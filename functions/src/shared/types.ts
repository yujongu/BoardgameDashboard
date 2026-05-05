import { Timestamp } from "firebase-admin/firestore";

// ---------------------------------------------------------------------------
// Collection document types — shapes of documents stored in Firestore.
// These reflect what is actually written to each collection.
// ---------------------------------------------------------------------------

/**
 * Stored document at `boardGames/{gameId}`.
 * Global read-only catalog of board games.
 */
export interface BoardGameDocument {
  name: string;
  thumbnailUrl?: string;
  publisher?: string;
  releaseYear?: number;
  minPlayers?: number;
  maxPlayers?: number;
  playTimeMinutes?: number;
  createdAt?: Timestamp;
}

// ---------------------------------------------------------------------------
// Input types — data sent by the client to callable Cloud Functions.
// Timestamps are ISO 8601 strings; the server converts them to Firestore
// Timestamps. Server-derived fields (createdBy, createdAt, etc.) are absent.
// ---------------------------------------------------------------------------

/**
 * One participant provided by the client when logging a play session.
 * `userId` is null for guest players who are not registered app users.
 */
export interface ParticipantInput {
  /** Registered user ID. Pass null explicitly for a guest player. */
  userId: string | null;
  /** Display name — required even for registered users (snapshot at play time). */
  name: string;
  /** Avatar URL snapshot. Optional. */
  photoUrl?: string;
  /** Whether this participant won the session. */
  isWinner: boolean;
  /** Numeric score. Optional — not all games track scores. */
  score?: number;
  /** Finish rank. Optional. */
  rank?: number;
  /** Team identifier for team-based games. Optional. */
  teamId?: string;
}

/**
 * Data sent by the client to create a new play session.
 * Server derives: `createdBy` (from auth), `participantCount`,
 * `participantIds`, and `createdAt`.
 */
export interface CreatePlayInput {
  /** Reference to the board game played. */
  gameId: string;
  /** Denormalized game name snapshot for fast UI reads. */
  gameName: string;
  /** When the session was played. ISO 8601 string. */
  playedAt: string;
  /** All participants in this session, including guests. */
  participants: ParticipantInput[];
  /** Optional physical or virtual location. */
  location?: string;
  /** Optional freeform session notes. */
  notes?: string;
}

// ---------------------------------------------------------------------------
// Document types — shapes of documents stored in Firestore.
// All timestamps are Firestore Timestamps. These types are never sent by the
// client directly; they are written exclusively by Cloud Functions.
// ---------------------------------------------------------------------------

/**
 * Stored document at `plays/{playId}`.
 * Source of truth for a single board game play session.
 */
export interface PlayDocument {
  /** Reference to `boardGames/{gameId}`. */
  gameId: string;
  /** Denormalized snapshot of the game name for fast UI reads. */
  gameName: string;
  /** When the session was played. */
  playedAt: Timestamp;
  /** UID of the user who logged this session. */
  createdBy: string;
  /** Total number of participants, derived from the participants subcollection. */
  participantCount: number;
  /**
   * Array of registered user IDs who participated.
   * Used for array-contains queries ("show plays I was in").
   * Guest participants are excluded.
   */
  participantIds: string[];
  /** Optional location. */
  location?: string;
  /** Optional session notes. */
  notes?: string;
  /** Server-set creation timestamp. */
  createdAt: Timestamp;
}

/**
 * Stored document at `plays/{playId}/participants/{participantId}`.
 * Represents one player's record within a play session.
 */
export interface ParticipantDocument {
  /**
   * Registered user ID. Null for guest players.
   * Optional field — may be absent if the document predates guest-null convention.
   */
  userId: string | null;
  /** Name snapshot at the time of the play. Used as fallback for guests. */
  name: string;
  /** Avatar URL snapshot at the time of the play. */
  photoUrl?: string;
  /** Whether this participant won the session. */
  isWinner: boolean;
  /** Numeric score. Optional. */
  score?: number;
  /** Finish rank. Optional. */
  rank?: number;
  /** Team identifier for team-based games. Optional. */
  teamId?: string;
  /** Server-set timestamp when this participant record was created. */
  joinedAt: Timestamp;
}

/**
 * Stored document at `stats/{userId}`.
 * Aggregated lifetime stats for a registered user.
 * Written and updated exclusively by Cloud Functions.
 */
export interface StatsDocument {
  /** Total number of play sessions this user has participated in. */
  totalGamesPlayed: number;
  /** Total number of play sessions this user has won. */
  totalWins: number;
  /** Timestamp of the most recent session. Absent if the user has no plays yet. */
  lastPlayedAt?: Timestamp;
}

/**
 * Stored document at `stats/{userId}/gameStats/{gameId}`.
 * Per-user, per-game aggregated stats.
 */
export interface GameStatsDocument {
  /** The game ID — redundant with the document path but stored for convenience. */
  gameId: string;
  /** Snapshot of the game name at the time of the last play. */
  gameName: string;
  /** Number of times this user has played this game. */
  playCount: number;
  /** Number of times this user has won this game. */
  winCount: number;
  /** Timestamp of the most recent session for this game. */
  lastPlayedAt?: Timestamp;
}

/**
 * Stored document at `users/{userId}/library/{gameId}`.
 * Derived, UI-optimized record of a game in the user's personal library.
 * Updated by Cloud Functions whenever a play session involving this game is written.
 */
export interface UserLibraryDocument {
  /** The game ID — matches the document ID and the `boardGames` collection. */
  gameId: string;
  /** Snapshot of the game name for UI display. */
  gameName: string;
  /** Thumbnail URL from the board game catalog. Optional. */
  thumbnailUrl?: string;
  /** Total plays of this game by this user. Starts at 0. */
  playCount: number;
  /** Total wins of this game by this user. Starts at 0. */
  winCount: number;
  /** Timestamp of the user's first recorded play of this game. */
  firstPlayedAt?: Timestamp;
  /** Timestamp of the user's most recent play of this game. */
  lastPlayedAt?: Timestamp;
  /** User's personal rating for this game. Optional. */
  rating?: number;
  /** Whether the user owns a physical or digital copy of this game. Starts as false. */
  isOwned: boolean;
  /** Whether the user has marked this game as a favourite. Optional. */
  favorite?: boolean;
}
