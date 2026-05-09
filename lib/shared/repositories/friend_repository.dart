import 'dart:developer' as dev;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend.dart';
import '../models/friend_request.dart';

// This system intentionally avoids joins with the users collection to minimize reads and latency.
// Friend data (name, photoUrl) is served entirely from friend subcollection docs and request
// snapshot fields written at send time. No users/{uid} reads occur in any friend flow.
class FriendRepository {
  FriendRepository._();
  static final instance = FriendRepository._();

  static const _tag = 'FriendRepository';

  FirebaseFunctions get _fn => FirebaseFunctions.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<List<FriendSummary>> getMyFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated — cannot load friends.');
    }

    dev.log('getMyFriends: calling for uid=${user.uid}', name: _tag);

    final HttpsCallableResult result;
    try {
      result = await _fn.httpsCallable('getMyFriends').call({});
    } catch (e, stack) {
      dev.log(
        'getMyFriends: Cloud Function call failed',
        name: _tag,
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }

    final raw = result.data;
    if (raw is! Map) {
      throw StateError(
        'getMyFriends: malformed payload — expected Map, got ${raw.runtimeType}',
      );
    }

    final rawList = Map<String, dynamic>.from(raw)['friends'];
    if (rawList is! List) {
      throw StateError(
        'getMyFriends: malformed payload — "friends" key missing or wrong type (got ${rawList.runtimeType})',
      );
    }

    final friends = rawList
        .whereType<Map>()
        .map((e) => FriendSummary.fromJson(Map<String, dynamic>.from(e)))
        .where((f) => f.userId.isNotEmpty)
        .toList();

    dev.log('getMyFriends: returned ${friends.length} friends', name: _tag);
    return friends;
  }

  // ─── Friend requests ───────────────────────────────────────────────────────

  Future<List<FriendRequestSummary>> getIncomingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final result = await _fn
        .httpsCallable('getIncomingFriendRequests')
        .call({});
    return _parseRequests(
      result.data,
      'requests',
      'fromUserId',
      'fromUserName',
      'fromUserPhotoUrl',
    );
  }

  Future<List<FriendRequestSummary>> getOutgoingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final result = await _fn
        .httpsCallable('getOutgoingFriendRequests')
        .call({});
    return _parseRequests(
      result.data,
      'requests',
      'toUserId',
      'toUserName',
      'toUserPhotoUrl',
    );
  }

  Future<void> sendFriendRequest(String toUserId) async {
    await _fn.httpsCallable('sendFriendRequest').call({'toUserId': toUserId});
  }

  Future<void> acceptRequest(String requestId) async {
    await _fn.httpsCallable('acceptFriendRequest').call({
      'requestId': requestId,
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await _fn.httpsCallable('rejectFriendRequest').call({
      'requestId': requestId,
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  List<FriendRequestSummary> _parseRequests(
    dynamic raw,
    String listKey,
    String userIdKey,
    String nameKey,
    String photoUrlKey,
  ) {
    if (raw is! Map) return [];
    final rawList = Map<String, dynamic>.from(raw)[listKey];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['requestId'] is String && e[userIdKey] is String)
        .map(
          (e) => FriendRequestSummary(
            requestId: e['requestId'] as String,
            userId: e[userIdKey] as String,
            name: (e[nameKey] as String?) ?? 'Unknown user',
            photoUrl: e[photoUrlKey] as String?,
            createdAt:
                DateTime.tryParse((e['createdAt'] as String?) ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snap = await _db
        .collection('userSearch')
        .where('name_lower', isGreaterThanOrEqualTo: q)
        .where('name_lower', isLessThan: '$q${String.fromCharCode(0xF8FF)}')
        .limit(20)
        .get();
    return snap.docs.where((d) => d.id != uid).map((d) {
      final data = d.data();
      return UserSearchResult(
        userId: d.id,
        name: (data['name'] as String?) ?? '',
        photoUrl: data['photoUrl'] as String?,
      );
    }).toList();
  }
}
