import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend.dart';
import '../models/friend_request.dart';
import 'repository_providers.dart';

class FriendListNotifier
    extends AutoDisposeStreamNotifier<List<FriendSummary>> {
  @override
  Stream<List<FriendSummary>> build() =>
      ref.read(friendRepositoryProvider).watchMyFriends();
}

final friendListProvider =
    StreamNotifierProvider.autoDispose<FriendListNotifier, List<FriendSummary>>(
      FriendListNotifier.new,
    );

// ─── Incoming requests ────────────────────────────────────────────────────────

class IncomingRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<FriendRequestSummary>> {
  @override
  Future<List<FriendRequestSummary>> build() =>
      ref.read(friendRepositoryProvider).getIncomingRequests();

  Future<bool> accept(String requestId) async {
    final prev = state;
    if (state.hasValue) {
      state = AsyncData(
        state.value!.where((r) => r.requestId != requestId).toList(),
      );
    }
    try {
      await ref.read(friendRepositoryProvider).acceptRequest(requestId);
      ref.invalidate(friendListProvider);
      return true;
    } catch (_) {
      state = prev;
      return false;
    }
  }

  Future<bool> reject(String requestId) async {
    final prev = state;
    if (state.hasValue) {
      state = AsyncData(
        state.value!.where((r) => r.requestId != requestId).toList(),
      );
    }
    try {
      await ref.read(friendRepositoryProvider).rejectRequest(requestId);
      return true;
    } catch (_) {
      state = prev;
      return false;
    }
  }
}

final incomingRequestsProvider =
    AsyncNotifierProvider.autoDispose<
      IncomingRequestsNotifier,
      List<FriendRequestSummary>
    >(IncomingRequestsNotifier.new);

// ─── Outgoing requests ────────────────────────────────────────────────────────

class OutgoingRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<FriendRequestSummary>> {
  @override
  Future<List<FriendRequestSummary>> build() =>
      ref.read(friendRepositoryProvider).getOutgoingRequests();

  Future<bool> cancel(String requestId) async {
    final prev = state;
    if (state.hasValue) {
      state = AsyncData(
        state.value!.where((r) => r.requestId != requestId).toList(),
      );
    }
    try {
      await ref.read(friendRepositoryProvider).cancelRequest(requestId);
      return true;
    } catch (_) {
      state = prev;
      return false;
    }
  }
}

final outgoingRequestsProvider =
    AsyncNotifierProvider.autoDispose<
      OutgoingRequestsNotifier,
      List<FriendRequestSummary>
    >(OutgoingRequestsNotifier.new);
