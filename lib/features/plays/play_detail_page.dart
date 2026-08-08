import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../library/campaign_record_section.dart';
import '../library/campaign_registry.dart';
import 'edit_play_page.dart';
import 'play_detail_controller.dart';

class PlayDetailPage extends ConsumerStatefulWidget {
  final PlaySummary initialData;

  const PlayDetailPage({super.key, required this.initialData});

  @override
  ConsumerState<PlayDetailPage> createState() => _PlayDetailPageState();
}

class _PlayDetailPageState extends ConsumerState<PlayDetailPage> {
  // Navigation-only flag — does not drive any UI rebuild.
  bool _mutated = false;
  bool _deleting = false;

  Future<void> _onEdit(PlayDetailState state) async {
    final notifier = ref.read(playDetailProvider(widget.initialData).notifier);
    final detail = notifier.buildCurrentPlayDetail();
    if (detail == null) return;

    final input = await Navigator.of(context).push<UpdatePlayInput>(
      MaterialPageRoute(builder: (_) => EditPlayPage(detail: detail)),
    );
    if (input == null || !mounted) return;

    _mutated = true;
    final error = await notifier.applyUpdate(input);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).playDetailSaveFailed,
            style: GoogleFonts.spaceGrotesk(color: context.colors.onSurface).kr,
          ),
          backgroundColor: context.colors.surfaceHigh,
        ),
      );
    }
  }

  String _coopLine(AppStrings s) {
    final d = widget.initialData;
    final result = d.outcome == 'win' ? s.coopTeamWon : s.coopTeamLost;
    final n = d.stageId == null ? null : int.tryParse(d.stageId!);
    if (n == null) return result;
    final axis = stageAxisLabel(s, coopSpecForGame(d.gameId)?.stageAxis);
    return '$result · ${s.stageLabelNumbered(axis, n)}';
  }

  Future<void> _onDelete() async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(
          s.playDeleteTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ).kr,
        ),
        content: Text(
          s.playDeleteBody,
          style: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 14,
          ).kr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              s.commonCancelCaps,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ).kr,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              s.playDeleteConfirm,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ).kr,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      // Called on the repository rather than through playDetailProvider: popping
      // disposes that notifier, so awaiting its future was unsafe — which is why
      // the result used to be discarded, hiding every failure.
      await ref
          .read(playRepositoryProvider)
          .deletePlay(widget.initialData.playId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.playDeleteFailed,
            style: GoogleFonts.spaceGrotesk(color: context.colors.onSurface).kr,
          ),
          backgroundColor: context.colors.surfaceHigh,
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = ref.watch(playDetailProvider(widget.initialData));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_mutated);
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.colors.appBarBackground,
              expandedHeight: kToolbarHeight,
              collapsedHeight: kToolbarHeight,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.primary),
                onPressed: () => Navigator.of(context).pop(_mutated),
              ),
              actions: [
                // Co-op plays are not editable in v1 (updatePlay is
                // winner-centric); hide the edit affordance for them.
                if (!widget.initialData.isCoop)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: state.participants != null
                          ? context.colors.primary
                          : context.colors.outline,
                      size: 20,
                    ),
                    tooltip: s.commonEdit,
                    onPressed: state.participants != null
                        ? () => _onEdit(state)
                        : null,
                  ),
                IconButton(
                  icon: _deleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.outline,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                  tooltip: s.commonDelete,
                  // Null while in flight so a second tap cannot fire a second
                  // delete before the first resolves.
                  onPressed: _deleting ? null : _onDelete,
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: context.colors.amberBorder),
              ),
              flexibleSpace: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 56, right: 108),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.gameName.toUpperCase(),
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

            if (widget.initialData.isCoop)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _CoopResultBanner(
                    win: widget.initialData.outcome == 'win',
                    line: _coopLine(s),
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.initialData.isCoop ? 12 : 24,
                  20,
                  0,
                ),
                child: _SessionInfo(
                  playedAt: state.playedAt,
                  location: state.location,
                  notes: state.notes,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _SectionHeader(
                  title: s.playDetailPlayers,
                  count: state.participantCount,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: _buildParticipantsSliver(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSliver(PlayDetailState state) {
    if (state.participantsError != null) {
      return SliverToBoxAdapter(
        child: _ParticipantsError(
          onRetry: () => ref
              .read(playDetailProvider(widget.initialData).notifier)
              .retryLoadParticipants(),
        ),
      );
    }
    if (state.participants == null) {
      return SliverToBoxAdapter(
        child: _ParticipantsSkeleton(count: state.participantCount),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ParticipantCard(participant: state.participants![i]),
        ),
        childCount: state.participants!.length,
      ),
    );
  }
}

// ─── Co-op result banner ──────────────────────────────────────────────────────

class _CoopResultBanner extends StatelessWidget {
  final bool win;
  final String line;

  const _CoopResultBanner({required this.win, required this.line});

  @override
  Widget build(BuildContext context) {
    final color = win ? context.colors.primary : context.colors.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: win
            ? context.colors.primary.withAlpha(18)
            : context.colors.surfaceHigh,
        border: Border.all(color: color.withAlpha(140)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(win ? Icons.flag : Icons.flag_outlined, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line,
              style: GoogleFonts.newsreader(
                color: win ? context.colors.primary : context.colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ).kr,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session info ─────────────────────────────────────────────────────────────

class _SessionInfo extends StatelessWidget {
  final DateTime playedAt;
  final String? location;
  final String? notes;

  const _SessionInfo({required this.playedAt, this.location, this.notes});

  static String _formatDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = dt.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: _formatDate(playedAt),
          ),
          if (location != null) ...[
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.location_on_outlined, text: location!),
          ],
          if (notes != null) ...[
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.notes_outlined, text: notes!),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.outline, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.onSurface,
              fontSize: 14,
            ).kr,
          ),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

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
                color: context.colors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ).kr,
            ),
            Text(
              AppStrings.of(context).playersCountCaps(count),
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

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _ParticipantsSkeleton extends StatelessWidget {
  final int count;

  const _ParticipantsSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _SkeletonCard(),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.outlineVariant),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 60,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Participants error ───────────────────────────────────────────────────────

class _ParticipantsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ParticipantsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.colors.outline, size: 32),
          const SizedBox(height: 12),
          Text(
            s.playDetailPlayersLoadFailed,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 12,
            ).kr,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              s.commonRetry,
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

// ─── Participant card ─────────────────────────────────────────────────────────

class _ParticipantCard extends StatelessWidget {
  final ParticipantResult participant;

  const _ParticipantCard({required this.participant});

  static String _formatScore(double score) => score == score.truncateToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isWinner = participant.isWinner;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isWinner
            ? context.colors.primary.withAlpha(18)
            : context.colors.surfaceHigh,
        border: Border.all(
          color: isWinner
              ? context.colors.primary.withAlpha(140)
              : context.colors.amberBorder,
          width: isWinner ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isWinner
                  ? context.colors.primary.withAlpha(30)
                  : context.colors.surface,
              border: Border.all(
                color: isWinner
                    ? context.colors.primary.withAlpha(100)
                    : context.colors.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.person_outline,
              color: isWinner ? context.colors.primary : context.colors.outline,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  style: GoogleFonts.newsreader(
                    color: isWinner
                        ? context.colors.primary
                        : context.colors.onSurface,
                    fontSize: 16,
                    fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
                  ).kr,
                ),
                if (participant.score != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.playDetailScore(_formatScore(participant.score!)),
                    style: GoogleFonts.spaceGrotesk(
                      color: context.colors.outline,
                      fontSize: 11,
                    ).kr,
                  ),
                ],
              ],
            ),
          ),
          if (isWinner)
            _Badge(label: s.playDetailWinner, color: context.colors.primary)
          else if (participant.rank != null)
            _Badge(
              label: s.playDetailRank(participant.rank!),
              color: context.colors.outline,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ).kr,
      ),
    );
  }
}
