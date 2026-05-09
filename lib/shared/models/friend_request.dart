class FriendRequestSummary {
  final String requestId;
  final String userId;
  final String name;
  final String? photoUrl;
  final DateTime createdAt;

  const FriendRequestSummary({
    required this.requestId,
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.createdAt,
  });
}
