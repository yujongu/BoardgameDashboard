import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/functions_service.dart';
import '../models/play.dart';

final recentPlaysProvider = FutureProvider.autoDispose<List<PlaySummary>>((
  ref,
) {
  return FunctionsService.instance.listMyPlays(limit: 10);
});

final libraryProvider = FutureProvider.autoDispose<List<LibraryEntry>>((ref) {
  return FunctionsService.instance.getMyLibrary();
});
