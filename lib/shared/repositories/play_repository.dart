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

  /// Fetches one page of the caller's plays, newest first, via the
  /// `listMyPlays` Cloud Function. Pass [cursor] (a previous page's
  /// [ListMyPlaysResult.nextCursor]) to fetch the following page.
  Future<ListMyPlaysResult> listMyPlays({
    int limit = 20,
    String? cursor,
  }) async {
    final result = await _fn.httpsCallable('listMyPlays').call({
      'limit': limit,
      'cursor': ?cursor,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final plays = (data['plays'] as List)
        .map((p) => PlaySummary.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    return ListMyPlaysResult(
      plays: plays,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<PlayDetail> getPlay(String playId) async {
    final playRef = _db.collection('plays').doc(playId);
    final playFuture = playRef.get();
    final participantsFuture = playRef.collection('participants').get();

    final playSnap = await playFuture;
    if (!playSnap.exists) throw Exception('Play $playId not found');
    final d = playSnap.data()!;

    final participantsSnap = await participantsFuture;

    return PlayDetail(
      playId: playSnap.id,
      gameId: d['gameId'] as String,
      gameName: d['gameName'] as String,
      playedAt: (d['playedAt'] as Timestamp).toDate(),
      createdBy: d['createdBy'] as String,
      participantCount: d['participantCount'] as int,
      location: d['location'] as String?,
      notes: d['notes'] as String?,
      mode: d['mode'] == 'coop' ? PlayMode.coop : PlayMode.competitive,
      outcome: d['outcome'] as String?,
      campaignId: d['campaignId'] as String?,
      stageId: d['stageId'] as String?,
      difficulty: d['difficulty'] as String?,
      teamScore: (d['teamScore'] as num?)?.toDouble(),
      participants: participantsSnap.docs
          .map((doc) => ParticipantResult.fromJson(doc.data()))
          .toList(),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPlayDoc(String playId) {
    return _db
        .collection('plays')
        .doc(playId)
        .snapshots()
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
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

  /// Plays that both the caller and [friendId] participated in, newest first.
  ///
  /// Firestore permits only one `array-contains` per query, so we fetch the
  /// caller's most recent plays (bounded by [scanLimit]) and client-filter for
  /// the friend. Reads are permitted because the caller is always a participant.
  Future<List<PlaySummary>> fetchSharedPlays(
    String friendId, {
    int scanLimit = 100,
  }) async {
    final uid = _uid;
    if (uid == null) return [];
    final qs = await _db
        .collection('plays')
        .where('participantIds', arrayContains: uid)
        .orderBy('playedAt', descending: true)
        .limit(scanLimit)
        .get();
    return qs.docs
        .where((d) => (d.data()['participantIds'] as List).contains(friendId))
        .map(_playSummaryFromDoc)
        .toList();
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
        .map((qs) => qs.docs.map(_playSummaryFromDoc).toList())
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
  }

  /// Lifetime cooperative session count for the caller.
  ///
  /// Co-op plays write no library entry, so they are invisible to
  /// [watchLibrary]; this counter is the only lifetime record that they
  /// happened. Emits 0 when the stats document or the field is absent —
  /// documents written before the field existed simply read as 0.
  Stream<int> watchCoopPlayCount() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('stats')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['totalCoopPlays'] as num?)?.toInt() ?? 0);
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
        })
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
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
      mode: d['mode'] == 'coop' ? PlayMode.coop : PlayMode.competitive,
      outcome: d['outcome'] as String?,
      stageId: d['stageId'] as String?,
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
