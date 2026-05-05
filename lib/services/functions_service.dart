import 'dart:developer' as dev;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/play.dart';

class FunctionsService {
  FunctionsService._();
  static final FunctionsService instance = FunctionsService._();

  FirebaseFunctions get _fn => FirebaseFunctions.instance;

  User _requireUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      dev.log(
        '[FunctionsService] ERROR: No authenticated user — aborting call',
        name: 'FunctionsService',
      );
      throw StateError('User must be logged in to call Firebase Functions');
    }
    dev.log(
      '[FunctionsService] Auth OK — UID: ${user.uid}',
      name: 'FunctionsService',
    );
    return user;
  }

  Future<List<PlaySummary>> listMyPlays({
    int limit = 20,
    String? cursor,
  }) async {
    _requireUser();

    final payload = <String, dynamic>{'limit': limit};
    if (cursor != null) payload['cursor'] = cursor;

    dev.log(
      '[FunctionsService] listMyPlays → payload: $payload',
      name: 'FunctionsService',
    );

    try {
      final result = await _fn.httpsCallable('listMyPlays').call(payload);
      final data = Map<String, dynamic>.from(result.data as Map);

      dev.log(
        '[FunctionsService] listMyPlays ← keys: ${data.keys}',
        name: 'FunctionsService',
      );

      final rawPlays = data['plays'] as List<dynamic>? ?? [];

      if (rawPlays.isEmpty) {
        dev.log(
          '[FunctionsService] listMyPlays EMPTY RESULT — '
          'check backend data for UID: ${FirebaseAuth.instance.currentUser?.uid}',
          name: 'FunctionsService',
        );
      } else {
        dev.log(
          '[FunctionsService] listMyPlays ← ${rawPlays.length} plays',
          name: 'FunctionsService',
        );
      }

      return rawPlays
          .map((p) => PlaySummary.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      dev.log(
        '[FunctionsService] listMyPlays FirebaseFunctionsException\n'
        '  code    : ${e.code}\n'
        '  message : ${e.message}\n'
        '  details : ${e.details}',
        name: 'FunctionsService',
      );
      rethrow;
    } catch (e, st) {
      dev.log(
        '[FunctionsService] listMyPlays ERROR: $e',
        name: 'FunctionsService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<LibraryEntry>> getMyLibrary() async {
    final user = _requireUser();
    dev.log(
      '[FunctionsService] getMyLibrary → UID: ${user.uid}',
      name: 'FunctionsService',
    );

    try {
      final result = await _fn.httpsCallable('getMyLibrary').call({});
      final data = Map<String, dynamic>.from(result.data as Map);

      dev.log(
        '[FunctionsService] getMyLibrary ← keys: ${data.keys}',
        name: 'FunctionsService',
      );

      final rawLibrary = data['library'] as List<dynamic>? ?? [];

      if (rawLibrary.isEmpty) {
        dev.log(
          '[FunctionsService] getMyLibrary EMPTY RESULT — '
          'check backend data for UID: ${user.uid}',
          name: 'FunctionsService',
        );
      } else {
        dev.log(
          '[FunctionsService] getMyLibrary ← ${rawLibrary.length} entries',
          name: 'FunctionsService',
        );
      }

      return rawLibrary
          .map(
            (e) => LibraryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      dev.log(
        '[FunctionsService] getMyLibrary FirebaseFunctionsException\n'
        '  code    : ${e.code}\n'
        '  message : ${e.message}\n'
        '  details : ${e.details}',
        name: 'FunctionsService',
      );
      rethrow;
    } catch (e, st) {
      dev.log(
        '[FunctionsService] getMyLibrary ERROR: $e',
        name: 'FunctionsService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> debugListMyPlays() async {
    dev.log('══════ debugListMyPlays START ══════', name: 'FunctionsService');
    try {
      final plays = await listMyPlays(limit: 5);
      dev.log('Result count: ${plays.length}', name: 'FunctionsService');
      if (plays.isNotEmpty) {
        final first = plays.first;
        dev.log(
          'First play → game: "${first.gameName}" | '
          'date: ${first.playedAt} | '
          'players: ${first.participantCount}',
          name: 'FunctionsService',
        );
      }
    } catch (e) {
      dev.log('debugListMyPlays FAILED: $e', name: 'FunctionsService');
    }
    dev.log('══════ debugListMyPlays END ══════', name: 'FunctionsService');
  }
}
