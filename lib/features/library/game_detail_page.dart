import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../plays/play_detail_page.dart';
import '../tools/presentation/widgets/tool_card.dart';
import 'campaign_registry.dart';
import 'campaign_record_section.dart';
import '../tools/registry/game_tools_registry.dart';

class GameDetailPage extends ConsumerStatefulWidget {
  final String gameId;
  final String gameName;

  const GameDetailPage({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  ConsumerState<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends ConsumerState<GameDetailPage> {
  late Future<List<PlaySummary>> _future;
  bool _mutated = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchPlays();
  }

  Future<List<PlaySummary>> _fetchPlays() {
    return ref.read(playRepositoryProvider).fetchPlaysByGame(widget.gameId);
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
            return _buildErrorScaffold(
              AppStrings.of(context).gameDetailUnexpectedEmpty,
            );
          }
          return _buildDataScaffold(snapshot.data!);
        },
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────────

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _simpleAppBar(),
      body: Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────

  Widget _buildErrorScaffold(Object error) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _simpleAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: context.colors.outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 13,
                ).kr,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _reload,
                child: Text(
                  AppStrings.of(context).commonRetry,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ).kr,
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
    final campaignSpec = campaignForGame(widget.gameId);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: context.colors.appBarBackground,
            expandedHeight: kToolbarHeight,
            collapsedHeight: kToolbarHeight,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.colors.primary),
              onPressed: () => Navigator.of(context).pop(_mutated),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: context.colors.amberBorder),
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
                      color: context.colors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ).kr,
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

          // Campaigns — shown for any cooperative game with a stage board.
          if (campaignSpec != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: CampaignSection(
                  gameId: widget.gameId,
                  gameName: widget.gameName,
                  spec: campaignSpec,
                ),
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
      backgroundColor: context.colors.appBarBackground,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: context.colors.primary),
        onPressed: () => Navigator.of(context).pop(_mutated),
      ),
      title: Text(
        widget.gameName.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.newsreader(
          color: context.colors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ).kr,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: context.colors.amberBorder),
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
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            '$playCount',
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.primary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ).kr,
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.of(context).homeStatPlays,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ).kr,
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
    final s = AppStrings.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              s.playHistoryTitle,
              style: GoogleFonts.newsreader(
                color: context.colors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ).kr,
            ),
            if (count > 0)
              Text(
                s.sessionsCount(count),
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

// ─── Play row ─────────────────────────────────────────────────────────────────

class _PlayRow extends StatelessWidget {
  final PlaySummary play;
  final VoidCallback onTap;

  const _PlayRow({required this.play, required this.onTap});

  String _subtitle(BuildContext context) {
    final s = AppStrings.of(context);
    if (!play.isCoop) return s.playersCount(play.participantCount);

    final result = play.outcome == 'win' ? s.coopTeamWon : s.coopTeamLost;
    final stageId = play.stageId;
    final n = stageId == null ? null : int.tryParse(stageId);
    if (n == null) return result;
    final axis = stageAxisLabel(s, coopSpecForGame(play.gameId)?.stageAxis);
    return '$result · ${s.stageLabelNumbered(axis, n)}';
  }

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
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border.all(color: context.colors.outlineVariant),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: context.colors.outline,
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
                      color: context.colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ).kr,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(context),
                    style: GoogleFonts.spaceGrotesk(
                      color: context.colors.outline,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ).kr,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.outlineVariant,
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
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.casino_outlined,
            color: context.colors.primary.withAlpha(80),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            s.gameDetailEmptyTitle,
            style: GoogleFonts.newsreader(
              color: context.colors.onSurfaceVariant,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ).kr,
          ),
          const SizedBox(height: 6),
          Text(
            s.gameDetailEmptySubtitle,
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

// ─── Tools section header ─────────────────────────────────────────────────────

class _ToolsSectionHeader extends StatelessWidget {
  const _ToolsSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.of(context).gameDetailTools,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ).kr,
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: context.colors.amberBorder),
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
          AppStrings.of(context).gameDetailNoTools,
          style: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 13,
          ).kr,
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
