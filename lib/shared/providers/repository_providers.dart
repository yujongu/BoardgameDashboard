import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/campaign_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/game_catalog_repository.dart';
import '../repositories/play_repository.dart';

/// Riverpod handles for the data-access singletons. Returning the existing
/// singleton keeps runtime behaviour identical, while letting tests override
/// each provider with a fake (`overrideWithValue(FakeRepo())`).
final playRepositoryProvider = Provider<PlayRepository>(
  (ref) => PlayRepository.instance,
);

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => FriendRepository.instance,
);

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => CampaignRepository.instance,
);

final gameCatalogRepositoryProvider = Provider<GameCatalogRepository>(
  (ref) => GameCatalogRepository.instance,
);
