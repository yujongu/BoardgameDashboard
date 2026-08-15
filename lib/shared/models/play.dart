/// Hard ceiling on participants in one play, independent of the game.
///
/// Mirrors `MAX_PARTICIPANTS` in `functions/src/shared/auth.ts`: createPlay and
/// updatePlay reject anything above it, so letting the UI go past this point
/// only produces a failed save. Every game in the catalog tops out at or below
/// this, so in practice the game's own maximum is what the user runs into.
const int kMaxParticipantsPerPlay = 20;

class ParticipantInput {
  const ParticipantInput({
    required this.userId,
    required this.name,
    required this.isWinner,
    this.score,
  });

  final String? userId;
  final String name;
  final bool isWinner;
  final double? score;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'isWinner': isWinner,
    if (score != null) 'score': score,
  };
}

/// Play mode discriminator. Competitive plays record a per-player winner;
/// cooperative plays record one shared team [outcome] and optionally advance a
/// campaign stage.
enum PlayMode { competitive, coop }

class CreatePlayInput {
  const CreatePlayInput({
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participants,
    this.location,
    this.notes,
    this.mode = PlayMode.competitive,
    this.outcome,
    this.campaignId,
    this.stageId,
    this.difficulty,
    this.teamScore,
  });

  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final List<ParticipantInput> participants;
  final String? location;
  final String? notes;

  // Cooperative fields (ignored when [mode] is competitive).
  final PlayMode mode;
  final String? outcome; // 'win' | 'loss'
  final String? campaignId;
  final String? stageId;
  final String? difficulty;
  final double? teamScore;

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'participants': participants.map((p) => p.toJson()).toList(),
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
    'mode': mode.name,
    if (outcome != null) 'outcome': outcome,
    if (campaignId != null) 'campaignId': campaignId,
    if (stageId != null) 'stageId': stageId,
    if (difficulty != null) 'difficulty': difficulty,
    if (teamScore != null) 'teamScore': teamScore,
  };
}

class UpdatePlayInput {
  const UpdatePlayInput({
    required this.playId,
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participants,
    this.location,
    this.notes,
  });

  final String playId;
  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final List<ParticipantInput> participants;
  final String? location;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'playId': playId,
    'gameId': gameId,
    'gameName': gameName,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'participants': participants.map((p) => p.toJson()).toList(),
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
  };
}

class PlaySummary {
  const PlaySummary({
    required this.playId,
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participantCount,
    this.mode = PlayMode.competitive,
    this.outcome,
    this.stageId,
  });

  final String playId;
  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final int participantCount;

  // Cooperative summary fields — null/competitive for competitive plays.
  final PlayMode mode;
  final String? outcome; // 'win' | 'loss'
  final String? stageId;

  bool get isCoop => mode == PlayMode.coop;

  @override
  bool operator ==(Object other) =>
      other is PlaySummary && other.playId == playId;

  @override
  int get hashCode => playId.hashCode;

  factory PlaySummary.fromJson(Map<String, dynamic> json) => PlaySummary(
    playId: json['playId'] as String,
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playedAt: DateTime.parse(json['playedAt'] as String),
    participantCount: json['participantCount'] as int,
    mode: _parseMode(json['mode']),
    outcome: json['outcome'] as String?,
    stageId: json['stageId'] as String?,
  );
}

PlayMode _parseMode(Object? raw) =>
    raw == 'coop' ? PlayMode.coop : PlayMode.competitive;

class ListMyPlaysResult {
  const ListMyPlaysResult({required this.plays, required this.nextCursor});

  final List<PlaySummary> plays;
  final String? nextCursor;
}

class ParticipantResult {
  const ParticipantResult({
    required this.userId,
    required this.name,
    required this.isWinner,
    this.score,
    this.rank,
  });

  final String? userId;
  final String name;
  final bool isWinner;
  final double? score;
  final int? rank;

  factory ParticipantResult.fromJson(Map<String, dynamic> json) =>
      ParticipantResult(
        userId: json['userId'] as String?,
        name: json['name'] as String,
        isWinner: json['isWinner'] as bool,
        score: (json['score'] as num?)?.toDouble(),
        rank: json['rank'] as int?,
      );
}

class PlayDetail {
  const PlayDetail({
    required this.playId,
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.createdBy,
    required this.participantCount,
    required this.participants,
    this.location,
    this.notes,
    this.mode = PlayMode.competitive,
    this.outcome,
    this.campaignId,
    this.stageId,
    this.difficulty,
    this.teamScore,
  });

  final String playId;
  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final String createdBy;
  final int participantCount;
  final List<ParticipantResult> participants;
  final String? location;
  final String? notes;

  // Cooperative fields — null/competitive for competitive plays.
  final PlayMode mode;
  final String? outcome; // 'win' | 'loss'
  final String? campaignId;
  final String? stageId;
  final String? difficulty;
  final double? teamScore;

  bool get isCoop => mode == PlayMode.coop;

  factory PlayDetail.fromJson(Map<String, dynamic> json) => PlayDetail(
    playId: json['playId'] as String,
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playedAt: DateTime.parse(json['playedAt'] as String),
    createdBy: json['createdBy'] as String,
    participantCount: json['participantCount'] as int,
    participants: (json['participants'] as List<dynamic>)
        .map(
          (p) =>
              ParticipantResult.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList(),
    location: json['location'] as String?,
    notes: json['notes'] as String?,
    mode: _parseMode(json['mode']),
    outcome: json['outcome'] as String?,
    campaignId: json['campaignId'] as String?,
    stageId: json['stageId'] as String?,
    difficulty: json['difficulty'] as String?,
    teamScore: (json['teamScore'] as num?)?.toDouble(),
  );
}

class LibraryEntry {
  const LibraryEntry({
    required this.gameId,
    required this.gameName,
    required this.playCount,
    required this.winCount,
    this.lastPlayedAt,
  });

  final String gameId;
  final String gameName;
  final int playCount;
  final int winCount;
  final DateTime? lastPlayedAt;

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playCount: json['playCount'] as int,
    winCount: json['winCount'] as int,
    lastPlayedAt: json['lastPlayedAt'] != null
        ? DateTime.parse(json['lastPlayedAt'] as String)
        : null,
  );
}
