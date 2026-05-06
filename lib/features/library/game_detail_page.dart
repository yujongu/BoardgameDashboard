import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/play.dart';
import '../../shared/repositories/play_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../plays/play_detail_page.dart';
import '../tools/presentation/widgets/tool_card.dart';
import '../tools/registry/game_tools_registry.dart';

class GameDetailPage extends StatefulWidget {
  final String gameId;
  final String gameName;

  const GameDetailPage({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  late Future<List<PlaySummary>> _future;
  bool _mutated = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchPlays();
  }

  Future<List<PlaySummary>> _fetchPlays() {
    return PlayRepository.instance.fetchPlaysByGame(widget.gameId);
  }

  void _reload() => setState(() => _future = _fetchPlays());

  Future<void> _openPlay(PlaySummary play) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PlayDetailPage(initialData: play)),
    );
    // Set _mutated before the mounted check so the flag is always propagated
    // to the caller even if this widget is being torn down concurrently.
    if (result == true) {
      _mutated = true;
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_mutated);
      },
      child: FutureBuilder<List<PlaySummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }
          if (snapshot.hasError) {
            return _buildErrorScaffold(snapshot.error!);
          }
          if (!snapshot.hasData) {
            return _buildErrorScaffold('Unexpected empty result');
          }
          return _buildDataScaffold(snapshot.data!);
        },
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────────

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: _simpleAppBar(),
      body: const Center(
        child: CircularProgressIndicator(color: kColorPrimary),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────

  Widget _buildErrorScaffold(Object error) {
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: _simpleAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: kColorOutline, size: 48),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _reload,
                child: Text(
                  'RETRY',
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Widget _buildDataScaffold(List<PlaySummary> plays) {
    return Scaffold(
      backgroundColor: kColorBackground,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF0A0905),
            expandedHeight: kToolbarHeight,
            collapsedHeight: kToolbarHeight,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kColorPrimary),
              onPressed: () => Navigator.of(context).pop(_mutated),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: kColorAmberBorder),
            ),
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 56, right: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.gameName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      color: kColorPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats box
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _StatsBox(playCount: plays.length),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _SectionHeader(count: plays.length),
            ),
          ),

          // Plays list or empty state
          plays.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyView())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlayRow(
                          play: plays[i],
                          onTap: () => _openPlay(plays[i]),
                        ),
                      ),
                      childCount: plays.length,
                    ),
                  ),
                ),

          // Tools section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _ToolsSectionHeader(),
            ),
          ),

          // Tools cards or empty state
          SliverToBoxAdapter(child: _ToolsContent(gameId: widget.gameId)),
        ],
      ),
    );
  }

  AppBar _simpleAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0905),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: kColorPrimary),
        onPressed: () => Navigator.of(context).pop(_mutated),
      ),
      title: Text(
        widget.gameName.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.newsreader(
          color: kColorPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kColorAmberBorder),
      ),
    );
  }
}

// ─── Stats box ────────────────────────────────────────────────────────────────

class _StatsBox extends StatelessWidget {
  final int playCount;

  const _StatsBox({required this.playCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            '$playCount',
            style: GoogleFonts.spaceGrotesk(
              color: kColorPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'PLAYS',
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

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int count;

  const _SectionHeader({required this.count});

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
              'Play History',
              style: GoogleFonts.newsreader(
                color: kColorPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            if (count > 0)
              Text(
                '$count ${count == 1 ? 'SESSION' : 'SESSIONS'}',
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

// ─── Play row ─────────────────────────────────────────────────────────────────

class _PlayRow extends StatelessWidget {
  final PlaySummary play;
  final VoidCallback onTap;

  const _PlayRow({required this.play, required this.onTap});

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
    final local = dt.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Icons.calendar_today_outlined,
                color: kColorOutline,
                size: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(play.playedAt),
                    style: GoogleFonts.newsreader(
                      color: kColorOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${play.participantCount} '
                    '${play.participantCount == 1 ? 'player' : 'players'}',
                    style: GoogleFonts.spaceGrotesk(
                      color: kColorOutline,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: kColorOutlineVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
            'No play history found',
            style: GoogleFonts.newsreader(
              color: kColorOnSurfaceVariant,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Log a play to see it here',
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Tools section header ─────────────────────────────────────────────────────

class _ToolsSectionHeader extends StatelessWidget {
  const _ToolsSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools',
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: kColorAmberBorder),
      ],
    );
  }
}

// ─── Tools content ────────────────────────────────────────────────────────────

class _ToolsContent extends StatelessWidget {
  final String gameId;

  const _ToolsContent({required this.gameId});

  @override
  Widget build(BuildContext context) {
    final tools = toolsForGame(gameId);
    if (tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Text(
          'No tools available yet.',
          style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        children: [
          for (int i = 0; i < tools.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            ToolCard(tool: tools[i]),
          ],
        ],
      ),
    );
  }
}
