import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/catalog_game.dart';
import '../providers/game_catalog_provider.dart';
import '../theme/app_theme.dart';

class GamePickerSheet extends ConsumerStatefulWidget {
  final void Function(String gameId, String name) onSelect;

  const GamePickerSheet({super.key, required this.onSelect});

  @override
  ConsumerState<GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends ConsumerState<GamePickerSheet> {
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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(gameCatalogProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Container(
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kColorOutlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'SELECT GAME',
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            Container(height: 1, color: kColorAmberBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
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
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.spaceGrotesk(
                          color: kColorOnSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Search games…',
                          hintStyle: GoogleFonts.spaceGrotesk(
                            color: kColorOutline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (catalog.loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: kColorOutline,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody(catalog)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GameCatalogState catalog) {
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
                'Could not load games',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.read(gameCatalogProvider.notifier).search(''),
                child: Text(
                  'RETRY',
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
          'No games found',
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
      itemBuilder: (_, i) => _GameTile(
        game: games[i],
        onTap: () => widget.onSelect(games[i].gameId, games[i].name),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final CatalogGame game;
  final VoidCallback onTap;

  const _GameTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
        child: Text(
          game.name,
          style: GoogleFonts.newsreader(
            color: kColorOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
