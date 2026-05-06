import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/play.dart';
import '../repositories/play_repository.dart';

final recentPlaysProvider = StreamProvider.autoDispose<List<PlaySummary>>((
  ref,
) {
  return PlayRepository.instance.watchRecentPlays(limit: 10);
});

final libraryProvider = StreamProvider.autoDispose<List<LibraryEntry>>((ref) {
  return PlayRepository.instance.watchLibrary();
});
