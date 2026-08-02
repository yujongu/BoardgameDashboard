import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/library/catalog_browse_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/catalog_game.dart';
import 'package:board_game_dashboard/shared/providers/repository_providers.dart';
import 'package:board_game_dashboard/shared/repositories/game_catalog_repository.dart';

/// Fake catalog repo — only the two methods the notifier calls are answered.
class _FakeCatalogRepo implements GameCatalogRepository {
  _FakeCatalogRepo(this.games, {this.throwOnLoad = false});
  final List<CatalogGame> games;
  final bool throwOnLoad;

  @override
  Future<List<CatalogGame>> fetchInitialGames() async {
    if (throwOnLoad) throw Exception('network down');
    return games;
  }

  @override
  Future<List<CatalogGame>> searchRemote(String query) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(List<CatalogGame> games, {bool throwOnLoad = false}) =>
    ProviderScope(
      overrides: [
        gameCatalogRepositoryProvider.overrideWithValue(
          _FakeCatalogRepo(games, throwOnLoad: throwOnLoad),
        ),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
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

  // D14: the preload's catch sets `games` to an empty list as well as `error`,
  // so gating the error UI on `games == null` made it unreachable and a failed
  // load was indistinguishable from a genuinely empty catalog.
  testWidgets('a failed load shows the error and Retry, not the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const [], throwOnLoad: true));
    await tester.pumpAndSettle();

    expect(find.text('Could not load games'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('No games found'), findsNothing);
  });

  testWidgets('the error survives clearing the search field', (tester) async {
    await tester.pumpWidget(_wrap(const [], throwOnLoad: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'azul');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Could not load games'), findsOneWidget);
    expect(find.text('No games found'), findsNothing);
  });
}
