import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/catalog_game.dart';
import '../../shared/providers/game_catalog_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'game_detail_page.dart';

/// Browse/search the full board-game catalog (not just games you've logged) and
/// open any game's detail page. Reuses [gameCatalogProvider] — the same hybrid
/// local+remote search that backs the play game-picker.
class CatalogBrowseScreen extends ConsumerStatefulWidget {
  const CatalogBrowseScreen({super.key});

  @override
  ConsumerState<CatalogBrowseScreen> createState() =>
      _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends ConsumerState<CatalogBrowseScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref
          .read(gameCatalogProvider.notifier)
          .search(_searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openGame(CatalogGame game) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            GameDetailPage(gameId: game.gameId, gameName: game.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final catalog = ref.watch(gameCatalogProvider);

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.catalogBrowseTitle,
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kColorAmberBorder),
        ),
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            remoteLoading: catalog.remoteLoading,
          ),
          Expanded(child: _buildBody(catalog)),
        ],
      ),
    );
  }

  Widget _buildBody(GameCatalogState catalog) {
    final s = AppStrings.of(context);
    if (catalog.loading && catalog.games == null) {
      return const Center(
        child: CircularProgressIndicator(color: kColorPrimary),
      );
    }

    if (catalog.error != null && catalog.games == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: kColorOutline, size: 32),
              const SizedBox(height: 12),
              Text(
                s.gamePickerLoadFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.read(gameCatalogProvider.notifier).reload(),
                child: Text(
                  s.commonRetry,
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final games = catalog.games ?? const [];
    if (games.isEmpty) {
      return Center(
        child: Text(
          s.gamePickerNoGames,
          style: GoogleFonts.newsreader(
            color: kColorOnSurfaceVariant,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: games.length,
      itemBuilder: (_, i) =>
          _GameTile(game: games[i], onTap: () => _openGame(games[i])),
    );
  }
}

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool remoteLoading;

  const _SearchField({required this.controller, required this.remoteLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: kColorOutline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: AppStrings.of(context).gamePickerSearchHint,
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (remoteLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: kColorOutline,
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, child) => value.text.isNotEmpty
                    ? GestureDetector(
                        onTap: controller.clear,
                        child: const Icon(
                          Icons.close,
                          color: kColorOutline,
                          size: 16,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Game tile ────────────────────────────────────────────────────────────────

class _GameTile extends StatelessWidget {
  final CatalogGame game;
  final VoidCallback onTap;

  const _GameTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final min = game.minPlayers;
    final max = game.maxPlayers;
    final range = (min != null && max != null)
        ? s.catalogPlayerRange(min, max)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.casino_outlined, color: kColorOutline, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: GoogleFonts.newsreader(
                      color: kColorOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (range != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      range,
                      style: GoogleFonts.spaceGrotesk(
                        color: kColorOutline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kColorOutline, size: 20),
          ],
        ),
      ),
    );
  }
}
