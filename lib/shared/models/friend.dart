class FriendSummary {
  final String userId;
  final String name;
  final String? photoUrl;

  const FriendSummary({
    required this.userId,
    required this.name,
    this.photoUrl,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> json) => FriendSummary(
    userId: (json['userId'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    photoUrl: json['photoUrl'] as String?,
  );
}

class UserSearchResult {
  final String userId;
  final String name;
  final String? photoUrl;

  const UserSearchResult({
    required this.userId,
    required this.name,
    this.photoUrl,
  });
}
