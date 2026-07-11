import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/crew_campaign.dart';

class CampaignRepository {
  CampaignRepository._();
  static final instance = CampaignRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String gameId) =>
      _db.collection('users').doc(uid).collection('campaigns').doc(gameId);

  Future<CrewCampaign?> fetchCampaign(String gameId) async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _doc(uid, gameId).get();
    final data = snap.data();
    return data == null ? null : CrewCampaign.fromJson(data);
  }

  Future<void> saveCampaign(String gameId, CrewCampaign campaign) async {
    final uid = _uid;
    if (uid == null) return;
    await _doc(
      uid,
      gameId,
    ).set({...campaign.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
  }
}
