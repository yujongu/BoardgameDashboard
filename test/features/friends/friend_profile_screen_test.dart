import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/friends/friend_profile_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/friend_profile.dart';
import 'package:board_game_dashboard/shared/models/play.dart';
import 'package:board_game_dashboard/shared/providers/repository_providers.dart';
import 'package:board_game_dashboard/shared/repositories/friend_repository.dart';
import 'package:board_game_dashboard/shared/repositories/play_repository.dart';

/// Fakes that answer only the methods the screen calls; everything else routes
/// through noSuchMethod (and would throw if unexpectedly invoked).
class _FakeFriendRepo implements FriendRepository {
  _FakeFriendRepo(this.profile);
  final FriendProfile profile;

  @override
  Future<FriendProfile> getFriendProfileDirect(String friendId) async =>
      profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlayRepo implements PlayRepository {
  _FakePlayRepo(this.shared);
  final List<PlaySummary> shared;

  @override
  Future<List<PlaySummary>> fetchSharedPlays(
    String friendId, {
    int scanLimit = 100,
  }) async => shared;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlaySummary _play(String id, String name) => PlaySummary(
  playId: id,
  gameId: id,
  gameName: name,
  playedAt: DateTime(2024, 1, 1),
  participantCount: 2,
);

Widget _wrap({
  required FriendProfile profile,
  required List<PlaySummary> shared,
}) => ProviderScope(
  overrides: [
    friendRepositoryProvider.overrideWithValue(_FakeFriendRepo(profile)),
    playRepositoryProvider.overrideWithValue(_FakePlayRepo(shared)),
  ],
  child: MaterialApp(
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: const FriendProfileScreen(friendId: 'f1', friendName: 'Bob'),
  ),
);

void main() {
  const profile = FriendProfile(
    name: 'Bob',
    totalGamesPlayed: 5,
    totalWins: 2,
    topGames: [],
  );

  testWidgets('renders shared plays with a count header', (tester) async {
    await tester.pumpWidget(
      _wrap(
        profile: profile,
        shared: [_play('p1', 'Azul'), _play('p2', 'Catan')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLAYED TOGETHER'), findsOneWidget);
    expect(find.text('2 games together'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('Catan'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no shared plays', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(profile: profile, shared: const []));
    await tester.pumpAndSettle();

    expect(find.text('PLAYED TOGETHER'), findsOneWidget);
    expect(find.text('No games played together yet'), findsOneWidget);
  });
}
