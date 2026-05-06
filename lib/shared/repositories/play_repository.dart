import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/play.dart';

class PlayRepository {
  PlayRepository._();
  static final instance = PlayRepository._();

  FirebaseFunctions get _fn => FirebaseFunctions.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> createPlay(CreatePlayInput input) async {
    final result = await _fn.httpsCallable('createPlay').call(input.toJson());
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['playId'] as String;
  }

  Future<void> updatePlay(UpdatePlayInput input) async {
    await _fn.httpsCallable('updatePlay').call(input.toJson());
  }

  Future<void> deletePlay(String playId) async {
    await _fn.httpsCallable('deletePlay').call({'playId': playId});
  }

  Future<PlayDetail> getPlay(String playId) async {
    final result = await _fn.httpsCallable('getPlay').call({'playId': playId});
    return PlayDetail.fromJson(Map<String, dynamic>.from(result.data as Map));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPlayDoc(String playId) {
    return _db.collection('plays').doc(playId).snapshots();
  }

  Future<List<PlaySummary>> fetchPlaysByGame(String gameId) async {
    final uid = _uid;
    if (uid == null) return [];
    final qs = await _db
        .collection('plays')
        .where('participantIds', arrayContains: uid)
        .where('gameId', isEqualTo: gameId)
        .orderBy('playedAt', descending: true)
        .get();
    return qs.docs.map(_playSummaryFromDoc).toList();
  }

  Stream<List<PlaySummary>> watchRecentPlays({int limit = 20}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('plays')
        .where('participantIds', arrayContains: uid)
        .orderBy('playedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map(_playSummaryFromDoc).toList());
  }

  Stream<List<LibraryEntry>> watchLibrary() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('library')
        .snapshots()
        .map((qs) {
          final entries = qs.docs.map(_libraryEntryFromDoc).toList();
          entries.sort((a, b) {
            if (a.lastPlayedAt == null) return 1;
            if (b.lastPlayedAt == null) return -1;
            return b.lastPlayedAt!.compareTo(a.lastPlayedAt!);
          });
          return entries;
        });
  }

  static PlaySummary _playSummaryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return PlaySummary(
      playId: doc.id,
      gameId: d['gameId'] as String,
      gameName: d['gameName'] as String,
      playedAt: (d['playedAt'] as Timestamp).toDate(),
      participantCount: d['participantCount'] as int,
    );
  }

  static LibraryEntry _libraryEntryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final ts = d['lastPlayedAt'];
    return LibraryEntry(
      gameId: doc.id,
      gameName: d['gameName'] as String,
      playCount: d['playCount'] as int,
      winCount: d['winCount'] as int,
      lastPlayedAt: ts != null ? (ts as Timestamp).toDate() : null,
    );
  }
}
