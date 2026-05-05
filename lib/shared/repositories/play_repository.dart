import 'package:cloud_functions/cloud_functions.dart';

import '../models/play.dart';

class PlayRepository {
  PlayRepository._();
  static final instance = PlayRepository._();

  FirebaseFunctions get _fn => FirebaseFunctions.instance;

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

  Future<ListMyPlaysResult> listMyPlays({int? limit, String? cursor}) async {
    final result = await _fn.httpsCallable('listMyPlays').call({
      'limit': ?limit,
      'cursor': ?cursor,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return ListMyPlaysResult(
      plays: (data['plays'] as List<dynamic>)
          .map((p) => PlaySummary.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<PlayDetail> getPlay(String playId) async {
    final result = await _fn.httpsCallable('getPlay').call({'playId': playId});
    return PlayDetail.fromJson(Map<String, dynamic>.from(result.data as Map));
  }

  Future<List<LibraryEntry>> getMyLibrary() async {
    final result = await _fn.httpsCallable('getMyLibrary').call({});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['library'] as List<dynamic>)
        .map((e) => LibraryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
