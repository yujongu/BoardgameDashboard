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

class CreatePlayInput {
  const CreatePlayInput({
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participants,
  });

  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final List<ParticipantInput> participants;

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'participants': participants.map((p) => p.toJson()).toList(),
  };
}

class UpdatePlayInput {
  const UpdatePlayInput({
    required this.playId,
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participants,
  });

  final String playId;
  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final List<ParticipantInput> participants;

  Map<String, dynamic> toJson() => {
    'playId': playId,
    'gameId': gameId,
    'gameName': gameName,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'participants': participants.map((p) => p.toJson()).toList(),
  };
}

class PlaySummary {
  const PlaySummary({
    required this.playId,
    required this.gameId,
    required this.gameName,
    required this.playedAt,
    required this.participantCount,
  });

  final String playId;
  final String gameId;
  final String gameName;
  final DateTime playedAt;
  final int participantCount;

  factory PlaySummary.fromJson(Map<String, dynamic> json) => PlaySummary(
    playId: json['playId'] as String,
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playedAt: DateTime.parse(json['playedAt'] as String),
    participantCount: json['participantCount'] as int,
  );
}

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

  factory PlayDetail.fromJson(Map<String, dynamic> json) => PlayDetail(
    playId: json['playId'] as String,
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    playedAt: DateTime.parse(json['playedAt'] as String),
    createdBy: json['createdBy'] as String,
    participantCount: json['participantCount'] as int,
    participants: (json['participants'] as List<dynamic>)
        .map((p) => ParticipantResult.fromJson(p as Map<String, dynamic>))
        .toList(),
    location: json['location'] as String?,
    notes: json['notes'] as String?,
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
