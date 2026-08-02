import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../models/catalog_game.dart';
import '../providers/game_catalog_provider.dart';
import '../theme/app_colors.dart';

class GamePickerSheet extends ConsumerStatefulWidget {
  final void Function(CatalogGame game) onSelect;

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
    final s = AppStrings.of(context);
    final catalog = ref.watch(gameCatalogProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.gamePickerTitle,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            Container(height: 1, color: context.colors.amberBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surfaceHigh,
                  border: Border.all(color: context.colors.amberBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: context.colors.outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.spaceGrotesk(
                          color: context.colors.onSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: s.gamePickerSearchHint,
                          hintStyle: GoogleFonts.spaceGrotesk(
                            color: context.colors.outline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    // remoteLoading is true only while a background Firestore
                    // fetch is in flight; local results are already visible so
                    // we only need a subtle inline indicator, not a blocker.
                    if (catalog.remoteLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: context.colors.outline,
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
    final s = AppStrings.of(context);
    if (catalog.loading && catalog.games == null) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      );
    }

    // See catalog_browse_screen.dart: `games` is non-null after a failed
    // preload, so gating on it hid this branch entirely.
    if (catalog.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: context.colors.outline,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                s.gamePickerLoadFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.read(gameCatalogProvider.notifier).reload(),
                child: Text(
                  s.commonRetry,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.primary,
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
            color: context.colors.onSurfaceVariant,
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
          _GameTile(game: games[i], onTap: () => widget.onSelect(games[i])),
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
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          game.name,
          style: GoogleFonts.newsreader(
            color: context.colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
