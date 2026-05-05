import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/functions_service.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/profile_app_bar.dart';

class HomeTab extends ConsumerStatefulWidget {
  final String displayName;
  final VoidCallback onProfileTap;

  const HomeTab({
    super.key,
    required this.displayName,
    required this.onProfileTap,
  });

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      // Defer so it doesn't race with the provider fetches on the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FunctionsService.instance.debugListMyPlays();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playsAsync = ref.watch(recentPlaysProvider);
    final libraryAsync = ref.watch(libraryProvider);

    return CustomScrollView(
      slivers: [
        ProfileAppBar(
          displayName: widget.displayName,
          onProfileTap: widget.onProfileTap,
        ),

        // Stats summary derived from library totals
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: libraryAsync.when(
              loading: () => const _StatsShimmer(),
              error: (_, _) => const SizedBox.shrink(),
              data: (library) => _StatsRow(library: library),
            ),
          ),
        ),

        // "Recent Plays" section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _SectionHeader(
              title: 'Recent Plays',
              subtitle: playsAsync.whenData((p) => p.length).valueOrNull != null
                  ? '${playsAsync.value!.length} sessions'
                  : null,
            ),
          ),
        ),

        // Plays list, loading, or error
        playsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: CircularProgressIndicator(color: kColorPrimary),
              ),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: _ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(recentPlaysProvider),
            ),
          ),
          data: (plays) => plays.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyPlaysView())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlayCard(play: plays[i]),
                      ),
                      childCount: plays.length,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<LibraryEntry> library;

  const _StatsRow({required this.library});

  @override
  Widget build(BuildContext context) {
    final totalPlays = library.fold(0, (sum, e) => sum + e.playCount);
    final totalWins = library.fold(0, (sum, e) => sum + e.winCount);
    final winRate = totalPlays == 0 ? 0 : (totalWins * 100 ~/ totalPlays);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _StatCell(value: '$totalPlays', label: 'PLAYS'),
          _Divider(),
          _StatCell(value: '$totalWins', label: 'WINS'),
          _Divider(),
          _StatCell(value: '$winRate%', label: 'WIN RATE'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: kColorPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOutline,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: kColorAmberBorder);
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: kColorPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: GoogleFonts.newsreader(
                color: kColorPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: kColorAmberBorder),
      ],
    );
  }
}

// ─── Play card ────────────────────────────────────────────────────────────────

class _PlayCard extends StatelessWidget {
  final PlaySummary play;

  const _PlayCard({required this.play});

  static String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final local = play.playedAt.toLocal();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kColorSurface,
              border: Border.all(color: kColorOutlineVariant),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Icon(
              Icons.casino_outlined,
              color: kColorOutline,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  play.gameName,
                  style: GoogleFonts.newsreader(
                    color: kColorOnSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${play.participantCount} ${play.participantCount == 1 ? 'player' : 'players'}',
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(local),
            style: GoogleFonts.spaceGrotesk(
              color: kColorOutline,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyPlaysView extends StatelessWidget {
  const _EmptyPlaysView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.casino_outlined,
            color: kColorPrimary.withAlpha(80),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No plays logged yet',
            style: GoogleFonts.newsreader(
              color: kColorOnSurfaceVariant,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to log your first session',
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 12),
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
          const Icon(Icons.error_outline, color: kColorOutline, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 12),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
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
    );
  }
}
