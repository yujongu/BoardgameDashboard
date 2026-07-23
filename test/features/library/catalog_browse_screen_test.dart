import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/library/catalog_browse_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/catalog_game.dart';
import 'package:board_game_dashboard/shared/providers/repository_providers.dart';
import 'package:board_game_dashboard/shared/repositories/game_catalog_repository.dart';

/// Fake catalog repo — only the two methods the notifier calls are answered.
class _FakeCatalogRepo implements GameCatalogRepository {
  _FakeCatalogRepo(this.games);
  final List<CatalogGame> games;

  @override
  Future<List<CatalogGame>> fetchInitialGames() async => games;

  @override
  Future<List<CatalogGame>> searchRemote(String query) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(List<CatalogGame> games) => ProviderScope(
  overrides: [
    gameCatalogRepositoryProvider.overrideWithValue(_FakeCatalogRepo(games)),
  ],
  child: MaterialApp(
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: const CatalogBrowseScreen(),
  ),
);

void main() {
  testWidgets('lists catalog games with player ranges', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        CatalogGame(gameId: 'azul', name: 'Azul', minPlayers: 2, maxPlayers: 4),
        CatalogGame(
          gameId: 'catan',
          name: 'Catan',
          minPlayers: 3,
          maxPlayers: 4,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('BROWSE GAMES'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('Catan'), findsOneWidget);
    expect(find.text('2–4 players'), findsOneWidget);
  });

  testWidgets('shows the empty state when the catalog is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('No games found'), findsOneWidget);
  });
}
