import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/play.dart';
import 'repository_providers.dart';

final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

final recentPlaysProvider = StreamProvider.autoDispose<List<PlaySummary>>((
  ref,
) {
  return ref.watch(playRepositoryProvider).watchRecentPlays(limit: 10);
});

final libraryProvider = StreamProvider.autoDispose<List<LibraryEntry>>((ref) {
  return ref.watch(playRepositoryProvider).watchLibrary();
});

/// Lifetime co-op session count. Separate from [libraryProvider] because co-op
/// plays never write a library entry — see PlayRepository.watchCoopPlayCount.
final coopPlayCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(playRepositoryProvider).watchCoopPlayCount();
});
