import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/play.dart';
import '../../shared/repositories/play_repository.dart';
import '../../shared/theme/app_theme.dart';
import 'play_detail_page.dart';

/// Full, paginated history of the caller's plays (newest first), backed by the
/// `listMyPlays` Cloud Function. Loads more pages on scroll until exhausted.
class PlayHistoryPage extends StatefulWidget {
  const PlayHistoryPage({super.key});

  @override
  State<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

class _PlayHistoryPageState extends State<PlayHistoryPage> {
  static const _pageSize = 20;

  final _repo = PlayRepository.instance;
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
      final result = await _repo.listMyPlays(limit: _pageSize, cursor: _cursor);
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
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PLAY HISTORY',
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
      return const Center(
        child: CircularProgressIndicator(color: kColorPrimary),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: kColorPrimary,
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
              'TAP TO RETRY',
              style: GoogleFonts.spaceGrotesk(
                color: kColorPrimary,
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
          'No plays logged yet',
          style: GoogleFonts.newsreader(
            color: kColorOnSurfaceVariant,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: kColorOutline, size: 40),
            const SizedBox(height: 16),
            Text(
              'Could not load your plays',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 13,
              ),
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
      ),
    );
  }
}
