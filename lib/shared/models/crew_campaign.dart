class CrewCampaign {
  final List<String> crewMembers;
  final int currentMission;

  const CrewCampaign({required this.crewMembers, required this.currentMission});

  factory CrewCampaign.fromJson(Map<String, dynamic> json) => CrewCampaign(
    crewMembers: List<String>.from(json['crewMembers'] as List? ?? const []),
    currentMission: (json['currentMission'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'crewMembers': crewMembers,
    'currentMission': currentMission,
  };
}
