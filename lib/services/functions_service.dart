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

  Future<PlayDetail> getPlay(String playId) async {
    _requireUser();
    dev.log(
      '[FunctionsService] getPlay → playId: $playId',
      name: 'FunctionsService',
    );

    try {
      final result = await _fn.httpsCallable('getPlay').call({
        'playId': playId,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      dev.log(
        '[FunctionsService] getPlay ← keys: ${data.keys}',
        name: 'FunctionsService',
      );
      return PlayDetail.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      dev.log(
        '[FunctionsService] getPlay FirebaseFunctionsException\n'
        '  code    : ${e.code}\n'
        '  message : ${e.message}\n'
        '  details : ${e.details}',
        name: 'FunctionsService',
      );
      rethrow;
    } catch (e, st) {
      dev.log(
        '[FunctionsService] getPlay ERROR: $e',
        name: 'FunctionsService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
