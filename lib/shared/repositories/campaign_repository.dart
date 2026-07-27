import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/campaign.dart';

/// Shared, table-scoped campaigns live in the top-level `campaigns` collection.
/// A user may belong to several campaigns of the same game (different tables);
/// every member reads and advances the one shared doc.
class CampaignRepository {
  CampaignRepository._();
  static final instance = CampaignRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('campaigns');

  /// The caller's campaigns (tables) for [gameId]. Requires the composite index
  /// on (memberIds array-contains, gameId) declared in firestore.indexes.json.
  Future<List<Campaign>> fetchCampaignsForGame(String gameId) async {
    final uid = _uid;
    if (uid == null) return [];
    final qs = await _col
        .where('memberIds', arrayContains: uid)
        .where('gameId', isEqualTo: gameId)
        .get();
    final campaigns = qs.docs.map((d) => _fromDoc(d.id, d.data())).toList();
    campaigns.sort((a, b) {
      final au = a.updatedAt, bu = b.updatedAt;
      if (au == null) return 1;
      if (bu == null) return -1;
      return bu.compareTo(au);
    });
    return campaigns;
  }

  Future<Campaign?> fetchCampaign(String id) async {
    final snap = await _col.doc(id).get();
    final data = snap.data();
    return data == null ? null : _fromDoc(snap.id, data);
  }

  /// Creates a new table/campaign owned by the caller. Returns the created
  /// [Campaign] (with an empty stage board).
  Future<Campaign> createCampaign({
    required String gameId,
    required String gameName,
    required List<String> roster,
    required List<String> memberIds,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    // The creator is always a member (Firestore rules require this).
    final members = {uid, ...memberIds}.toList();
    final doc = _col.doc();
    await doc.set({
      'gameId': gameId,
      'gameName': gameName,
      'memberIds': members,
      'roster': roster,
      'stages': <String, dynamic>{},
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return Campaign(
      id: doc.id,
      gameId: gameId,
      gameName: gameName,
      memberIds: members,
      roster: roster,
      stages: const {},
      createdBy: uid,
    );
  }

  /// Persists manual edits (roster changes, manual stage toggles from the
  /// board). Co-op play logging advances stages server-side, not here.
  Future<void> saveCampaign(Campaign campaign) async {
    await _col.doc(campaign.id).set({
      'roster': campaign.roster,
      'stages': campaign.stages.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Campaign _fromDoc(String id, Map<String, dynamic> data) =>
      Campaign.fromJson(id, _timestampsToDates(data));

  // The Campaign model is Firebase-free, so convert Timestamps to DateTime
  // (top-level updatedAt and each stage's lastPlayedAt) before decoding.
  Map<String, dynamic> _timestampsToDates(Map<String, dynamic> data) {
    final stages = (data['stages'] as Map?)?.map((k, v) {
      final m = Map<String, dynamic>.from(v as Map);
      final ts = m['lastPlayedAt'];
      if (ts is Timestamp) m['lastPlayedAt'] = ts.toDate();
      return MapEntry(k, m);
    });
    final updatedAt = data['updatedAt'];
    return {
      ...data,
      'stages': ?stages,
      if (updatedAt is Timestamp) 'updatedAt': updatedAt.toDate(),
    };
  }
}
