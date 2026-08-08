import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/profile_app_bar.dart';
import 'catalog_browse_screen.dart';
import 'game_detail_page.dart';

class LibraryTab extends ConsumerStatefulWidget {
  final String displayName;
  final VoidCallback onProfileTap;

  const LibraryTab({
    super.key,
    required this.displayName,
    required this.onProfileTap,
  });

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  void _openGame(LibraryEntry entry) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            GameDetailPage(gameId: entry.gameId, gameName: entry.gameName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);

    return CustomScrollView(
      slivers: [
        ProfileAppBar(
          displayName: widget.displayName,
          onProfileTap: widget.onProfileTap,
          trailing: IconButton(
            icon: Icon(Icons.travel_explore, color: context.colors.primary),
            tooltip: AppStrings.of(context).catalogBrowseTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CatalogBrowseScreen()),
            ),
          ),
        ),
        libraryAsync.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: _ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(libraryProvider),
            ),
          ),
          data: (library) => library.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyLibraryView())
              : _LibraryList(library: library, onCardTap: _openGame),
        ),
      ],
    );
  }
}

// ─── List ─────────────────────────────────────────────────────────────────────

class _LibraryList extends StatelessWidget {
  final List<LibraryEntry> library;
  final void Function(LibraryEntry) onCardTap;

  const _LibraryList({required this.library, required this.onCardTap});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _SectionHeader(count: library.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LibraryCard(
                  entry: library[i],
                  onTap: () => onCardTap(library[i]),
                ),
              ),
              childCount: library.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int count;

  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              s.libraryCollection,
              style: GoogleFonts.newsreader(
                color: context.colors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ).kr,
            ),
            Text(
              s.gamesCount(count),
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ).kr,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: context.colors.amberBorder),
      ],
    );
  }
}

// ─── Library card ─────────────────────────────────────────────────────────────

class _LibraryCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onTap;

  const _LibraryCard({required this.entry, required this.onTap});

  static const _darkPalette = [
    [Color(0xFF1A2A1A), Color(0xFF2D4A1E)],
    [Color(0xFF1A1A2A), Color(0xFF1E2A4A)],
    [Color(0xFF2A1A1A), Color(0xFF4A2A1E)],
    [Color(0xFF1A2020), Color(0xFF1E3A3A)],
    [Color(0xFF201A2A), Color(0xFF3A1E4A)],
    [Color(0xFF2A2010), Color(0xFF4A3A10)],
  ];

  // Same six hues as the dark palette, as tints instead of shades.
  static const _lightPalette = [
    [Color(0xFFDCE8D2), Color(0xFFB9D3A0)],
    [Color(0xFFD9DFF0), Color(0xFFAEC0E4)],
    [Color(0xFFF0DCD4), Color(0xFFE0B49C)],
    [Color(0xFFD4E6E6), Color(0xFFA6CCCC)],
    [Color(0xFFE2D9EC), Color(0xFFC0A8D8)],
    [Color(0xFFEFE4C4), Color(0xFFDCC68A)],
  ];

  List<Color> _gradientColors(Brightness brightness) {
    final palette = brightness == Brightness.dark
        ? _darkPalette
        : _lightPalette;
    final idx = entry.gameId.hashCode.abs() % palette.length;
    return palette[idx];
  }

  double get _winRate =>
      entry.playCount == 0 ? 0 : entry.winCount / entry.playCount;

  int get _winPercent => (_winRate * 100).round();

  static String _formatLastPlayed(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = _gradientColors(Theme.of(context).brightness);
    final lastPlayed = entry.lastPlayedAt;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Game color swatch
            Container(
              width: 80,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Icon(
                Icons.casino_outlined,
                color: context.colors.primary.withAlpha(50),
                size: 32,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.gameName,
                            style: GoogleFonts.newsreader(
                              color: context.colors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ).kr,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_winPercent%',
                          style: GoogleFonts.spaceGrotesk(
                            color: context.colors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ).kr,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Win rate bar
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _winRate.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          s.libraryWinsShort(entry.winCount),
                          style: GoogleFonts.spaceGrotesk(
                            color: context.colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ).kr,
                        ),
                        Text(
                          s.libraryPlaysSuffix(entry.playCount),
                          style: GoogleFonts.spaceGrotesk(
                            color: context.colors.outline,
                            fontSize: 10,
                          ).kr,
                        ),
                        if (lastPlayed != null) ...[
                          const Spacer(),
                          Text(
                            _formatLastPlayed(lastPlayed.toLocal()),
                            style: GoogleFonts.spaceGrotesk(
                              color: context.colors.outlineVariant,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ).kr,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: context.colors.primary.withAlpha(80),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            s.libraryEmptyTitle,
            style: GoogleFonts.newsreader(
              color: context.colors.onSurfaceVariant,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ).kr,
          ),
          const SizedBox(height: 6),
          Text(
            s.libraryEmptySubtitle,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 12,
            ).kr,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.colors.outline, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 12,
            ).kr,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              AppStrings.of(context).commonRetry,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ).kr,
            ),
          ),
        ],
      ),
    );
  }
}
