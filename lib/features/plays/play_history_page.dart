import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_colors.dart';
import 'play_detail_page.dart';

/// Full, paginated history of the caller's plays (newest first), backed by the
/// `listMyPlays` Cloud Function. Loads more pages on scroll until exhausted.
class PlayHistoryPage extends ConsumerStatefulWidget {
  const PlayHistoryPage({super.key});

  @override
  ConsumerState<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

class _PlayHistoryPageState extends ConsumerState<PlayHistoryPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<PlaySummary> _plays = [];

  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(playRepositoryProvider)
          .listMyPlays(limit: _pageSize, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _plays.addAll(result.plays);
        _cursor = result.nextCursor;
        _hasMore = result.nextCursor != null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.of(context).playHistoryTitleCaps,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Hard failure with nothing loaded yet.
    if (_error != null && _plays.isEmpty) {
      return _ErrorView(onRetry: _loadNextPage);
    }
    // First page still loading.
    if (_plays.isEmpty && _loading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      );
    }
    if (_plays.isEmpty) {
      return const _EmptyView();
    }

    // +1 row for the trailing loading / error / end indicator.
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _plays.length + 1,
      itemBuilder: (context, i) {
        if (i == _plays.length) return _buildFooter();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlayRow(
            play: _plays[i],
            onTap: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PlayDetailPage(initialData: _plays[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: context.colors.primary,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: GestureDetector(
            onTap: _loadNextPage,
            child: Text(
              AppStrings.of(context).historyTapToRetry,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    // No more pages.
    return const SizedBox(height: 8);
  }
}

// ─── Play row ─────────────────────────────────────────────────────────────────

class _PlayRow extends StatelessWidget {
  final PlaySummary play;
  final VoidCallback onTap;

  const _PlayRow({required this.play, required this.onTap});

  static const _months = [
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

  static String _formatDate(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  @override
  Widget build(BuildContext context) {
    final local = play.playedAt.toLocal();
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
                Icons.casino_outlined,
                color: context.colors.outline,
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
                      color: context.colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppStrings.of(context).playersCount(play.participantCount),
                    style: GoogleFonts.spaceGrotesk(
                      color: context.colors.outline,
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
                color: context.colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppStrings.of(context).homeEmptyTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.onSurfaceVariant,
            fontSize: 18,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: context.colors.outline, size: 40),
            const SizedBox(height: 16),
            Text(
              s.historyLoadFailed,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
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
}
