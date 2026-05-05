import 'package:cloud_functions/cloud_functions.dart';

import '../models/play.dart';

class PlayRepository {
  PlayRepository._();
  static final instance = PlayRepository._();

  FirebaseFunctions get _fn => FirebaseFunctions.instance;

  Future<String> createPlay(CreatePlayInput input) async {
    final result = await _fn.httpsCallable('createPlay').call(input.toJson());
    return (result.data as Map<String, dynamic>)['playId'] as String;
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
    final data = result.data as Map<String, dynamic>;
    return ListMyPlaysResult(
      plays: (data['plays'] as List<dynamic>)
          .map((p) => PlaySummary.fromJson(p as Map<String, dynamic>))
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<PlayDetail> getPlay(String playId) async {
    final result = await _fn.httpsCallable('getPlay').call({'playId': playId});
    return PlayDetail.fromJson(result.data as Map<String, dynamic>);
  }

  Future<List<LibraryEntry>> getMyLibrary() async {
    final result = await _fn.httpsCallable('getMyLibrary').call({});
    final data = result.data as Map<String, dynamic>;
    return (data['library'] as List<dynamic>)
        .map((e) => LibraryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
