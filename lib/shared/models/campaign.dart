/// A shared, table-scoped cooperative campaign.
///
/// A campaign belongs to a *table* (its own document id), not to a single user:
/// several players share one campaign doc, and advancing it advances it for
/// everyone. `memberIds` lists the registered players (for Firestore rules and
/// querying); `roster` holds display names including unregistered guests.
///
/// Stages are keyed by a stage id. Linear boards (The Crew) use "1".."N";
/// non-linear boards (Gloomhaven) use scenario ids. One shape serves both.
///
/// Kept free of Firebase types on purpose: the repository converts Firestore
/// Timestamps to [DateTime] before constructing, and `cloud_firestore`
/// serializes the [DateTime]s in [toJson] back to Timestamps on write.
class CampaignStage {
  final bool completed;
  final int sessionCount;
  final String? lastOutcome; // 'win' | 'loss'
  final DateTime? lastPlayedAt;

  const CampaignStage({
    this.completed = false,
    this.sessionCount = 0,
    this.lastOutcome,
    this.lastPlayedAt,
  });

  factory CampaignStage.fromJson(Map<String, dynamic> json) => CampaignStage(
    completed: json['completed'] as bool? ?? false,
    sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
    lastOutcome: json['lastOutcome'] as String?,
    lastPlayedAt: json['lastPlayedAt'] as DateTime?,
  );

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'sessionCount': sessionCount,
    if (lastOutcome != null) 'lastOutcome': lastOutcome,
    if (lastPlayedAt != null) 'lastPlayedAt': lastPlayedAt,
  };
}

/// One seat at a table. [userId] is null for a guest — someone who plays but
/// has no account, so they are shown by name and nothing is written for them.
class CampaignMember {
  final String name;
  final String? userId;

  const CampaignMember({required this.name, this.userId});

  bool get isGuest => userId == null;

  factory CampaignMember.fromJson(Map<String, dynamic> json) => CampaignMember(
    name: json['name'] as String? ?? '',
    userId: json['userId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (userId != null) 'userId': userId,
  };
}

class Campaign {
  final String id;
  final String gameId;
  final String gameName;

  /// Registered members' uids, denormalized from [participants] so Firestore
  /// rules and the `array-contains` table query can use it (neither can reach
  /// into a map inside an array). Frozen at creation.
  final List<String> memberIds;

  /// Everyone at the table, guests included. Frozen at creation: a table's
  /// seats cannot be added to or removed from once it exists.
  final List<CampaignMember> participants;

  final Map<String, CampaignStage> stages;
  final String? createdBy;
  final DateTime? updatedAt;

  const Campaign({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.memberIds,
    required this.participants,
    required this.stages,
    this.createdBy,
    this.updatedAt,
  });

  factory Campaign.fromJson(String id, Map<String, dynamic> json) => Campaign(
    id: id,
    gameId: json['gameId'] as String,
    gameName: json['gameName'] as String,
    memberIds: List<String>.from(json['memberIds'] as List? ?? const []),
    participants: ((json['participants'] as List?) ?? const [])
        .map(
          (e) => CampaignMember.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    stages: ((json['stages'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(
        key as String,
        CampaignStage.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    ),
    createdBy: json['createdBy'] as String?,
    updatedAt: json['updatedAt'] as DateTime?,
  );

  /// The document body written on create (server fills createdAt/updatedAt).
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'memberIds': memberIds,
    'participants': participants.map((p) => p.toJson()).toList(),
    'stages': stages.map((k, v) => MapEntry(k, v.toJson())),
    if (createdBy != null) 'createdBy': createdBy,
  };

  /// Display names of everyone at the table, in seat order.
  List<String> get participantNames => [for (final p in participants) p.name];

  bool isStageCompleted(int stage) => stages['$stage']?.completed ?? false;

  /// Number of logged attempts ("tries") recorded against [stage]. Reads the
  /// per-stage `sessionCount`, which the server increments once per attempt.
  int triesFor(int stage) => stages['$stage']?.sessionCount ?? 0;

  /// Lowest incomplete stage on a linear board of [stageCount] stages,
  /// clamped to [1, stageCount]. Used to default the stage picker and to
  /// render The Crew's "current mission".
  int nextIncompleteStage(int stageCount) {
    for (var i = 1; i <= stageCount; i++) {
      if (!isStageCompleted(i)) return i;
    }
    return stageCount;
  }

  int get completedCount => stages.values.where((s) => s.completed).length;

  /// Only [stages] varies over a table's life — the seats are fixed at
  /// creation, so there is deliberately no way to copy with new members.
  Campaign copyWith({Map<String, CampaignStage>? stages}) => Campaign(
    id: id,
    gameId: gameId,
    gameName: gameName,
    memberIds: memberIds,
    participants: participants,
    stages: stages ?? this.stages,
    createdBy: createdBy,
    updatedAt: updatedAt,
  );
}
