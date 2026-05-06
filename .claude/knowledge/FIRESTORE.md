collections:

  boardGames:
    description: Global boardgame catalog (read-only, no user data)
    documentId: gameId
    fields:
      name:
        type: string
        required: true
      thumbnailUrl:
        type: string
        required: false
      publisher:
        type: string
        required: false
      releaseYear:
        type: number
        required: false
      minPlayers:
        type: number
        required: false
      maxPlayers:
        type: number
        required: false
      playTimeMinutes:
        type: number
        required: false
      createdAt:
        type: timestamp
        required: false
        note: only for internal catalog management (not user-related)

  users:
    description: App users
    documentId: userId
    fields:
      name:
        type: string
        required: true
      email:
        type: string
        required: false
      photoUrl:
        type: string
        required: false
      createdAt:
        type: timestamp
        required: true

  plays:
    description: One boardgame play session (source of truth)
    documentId: playId
    fields:
      gameId:
        type: string
        required: true
        ref: boardGames.gameId
      gameName:
        type: string
        required: true
        note: snapshot for fast UI
      playedAt:
        type: timestamp
        required: true
      createdBy:
        type: string
        required: true
        ref: users.userId
      participantCount:
        type: number
        required: true
      participantIds:
        type: array<string>
        required: true
        note: used for querying user plays
      location:
        type: string
        required: false
      notes:
        type: string
        required: false
      createdAt:
        type: timestamp
        required: true

  participants:
    description: Participants of a play session
    path: plays/{playId}/participants/{participantId}
    documentId: participantId
    fields:
      userId:
        type: string
        required: false
        ref: users.userId
        note: null if guest
      name:
        type: string
        required: true
        note: snapshot (guest or user name at time of play)
      photoUrl:
        type: string
        required: false
        note: snapshot for UI
      isWinner:
        type: boolean
        required: true
      score:
        type: number
        required: false
      rank:
        type: number
        required: false
      teamId:
        type: string
        required: false
      joinedAt:
        type: timestamp
        required: true

  stats:
    description: Aggregated stats per user
    documentId: userId
    fields:
      totalGamesPlayed:
        type: number
        required: true
      totalWins:
        type: number
        required: true
      lastPlayedAt:
        type: timestamp
        required: false

  gameStats:
    description: Per-user per-game stats
    path: stats/{userId}/gameStats/{gameId}
    documentId: gameId
    fields:
      gameId:
        type: string
        required: true
      gameName:
        type: string
        required: true
      playCount:
        type: number
        required: true
      winCount:
        type: number
        required: true
      lastPlayedAt:
        type: timestamp
        required: false

  userLibrary:
    description: User's boardgame library (derived + UI optimized)
    path: users/{userId}/library/{gameId}
    documentId: gameId
    fields:
      gameId:
        type: string
        required: true
      gameName:
        type: string
        required: true
        note: snapshot for UI
      thumbnailUrl:
        type: string
        required: false
      playCount:
        type: number
        required: true
        default: 0
      winCount:
        type: number
        required: true
        default: 0
      firstPlayedAt:
        type: timestamp
        required: false
      lastPlayedAt:
        type: timestamp
        required: false
      rating:
        type: number
        required: false
      isOwned:
        type: boolean
        required: true
        default: false
      favorite:
        type: boolean
        required: false
