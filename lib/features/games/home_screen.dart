import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/dashboard_state.dart';
import '../../shared/models/game.dart';
import '../../shared/theme/app_theme.dart';
import '../tools/lost_cities/lost_cities_calculator_screen.dart';
import 'add_game_screen.dart';

class HomeScreen extends StatefulWidget {
  final DashboardState state;

  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  void _openAddGame() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddGameScreen(state: widget.state)),
    );
  }

  void _openGame(GameStats stats) {
    final route = switch (stats.game.id) {
      'lost_cities' => MaterialPageRoute(
        builder: (_) => const LostCitiesCalculatorScreen(),
      ),
      _ => MaterialPageRoute(
        builder: (_) => _PlaceholderGameScreen(stats: stats),
      ),
    };
    Navigator.of(context).push(route);
  }

  int? _featuredIndex(List<GameStats> games) {
    if (games.isEmpty) return null;
    int bestIdx = 0;
    for (int i = 1; i < games.length; i++) {
      if (games[i].winRate > games[bestIdx].winRate) bestIdx = i;
    }
    return games[bestIdx].winRate > 0.5 ? bestIdx : null;
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.state.trackedGames;
    final featuredIdx = _featuredIndex(games);

    return Scaffold(
      backgroundColor: kColorBackground,
      body: CustomScrollView(
        slivers: [
          _AppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _SectionHeader(count: games.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _openGame(games[i]),
                    child: i == featuredIdx
                        ? _FeaturedCard(stats: games[i])
                        : _CompactCard(stats: games[i]),
                  ),
                ),
                childCount: games.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _AddFab(onTap: _openAddGame),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0A0905),
      expandedHeight: 64,
      collapsedHeight: 64,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: kColorAmberBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _ProfileAvatar(),
                const SizedBox(width: 14),
                Text(
                  'ARCHEON',
                  style: GoogleFonts.newsreader(
                    color: kColorPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kColorPrimary.withAlpha(140), width: 1.5),
        color: kColorSurfaceHigh,
      ),
      child: ClipOval(
        child: Icon(
          Icons.person,
          color: kColorPrimary.withAlpha(180),
          size: 22,
        ),
      ),
    );
  }
}

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
            Expanded(
              child: Text(
                'Boardgame Collections',
                style: GoogleFonts.newsreader(
                  color: kColorPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count Discovered',
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

// Full-width featured card for the first game
class _FeaturedCard extends StatelessWidget {
  final GameStats stats;

  const _FeaturedCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _StoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              _GameImagePlaceholder(height: 160, game: stats.game),
              Positioned(
                top: 12,
                left: 12,
                child: _RarityBadge(winPercent: stats.winPercent),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, kColorSurfaceHigh],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stats.game.name,
                        style: GoogleFonts.newsreader(
                          color: kColorOnSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${stats.winPercent}%',
                          style: GoogleFonts.spaceGrotesk(
                            color: kColorPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'WIN RATE',
                          style: GoogleFonts.spaceGrotesk(
                            color: kColorOutline,
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CategoryChips(category: stats.game.category),
                const SizedBox(height: 12),
                _WinBar(winRate: stats.winRate),
                const SizedBox(height: 6),
                _PlayStats(stats: stats),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact card for subsequent games
class _CompactCard extends StatelessWidget {
  final GameStats stats;

  const _CompactCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _StoneCard(
      child: Row(
        children: [
          _GameImagePlaceholder(
            height: 100,
            width: 90,
            game: stats.game,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stats.game.name,
                          style: GoogleFonts.newsreader(
                            color: kColorOnSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${stats.winPercent}%',
                        style: GoogleFonts.spaceGrotesk(
                          color: kColorPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats.game.category.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: kColorOutline,
                      fontSize: 9,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _WinBar(winRate: stats.winRate),
                  const SizedBox(height: 6),
                  _PlayStats(stats: stats),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoneCard extends StatelessWidget {
  final Widget child;

  const _StoneCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Chiseled inset effect
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kColorPrimary.withAlpha(12),
                    Colors.transparent,
                    Colors.black.withAlpha(60),
                  ],
                ),
              ),
            ),
          ),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: child),
        ],
      ),
    );
  }
}

class _GameImagePlaceholder extends StatelessWidget {
  final double height;
  final double? width;
  final Game game;
  final BorderRadius? borderRadius;

  const _GameImagePlaceholder({
    required this.height,
    required this.game,
    this.width,
    this.borderRadius,
  });

  // Map each game to a distinct dark color pair for its placeholder gradient
  List<Color> get _colors {
    const palette = [
      [Color(0xFF1A2A1A), Color(0xFF2D4A1E)],
      [Color(0xFF1A1A2A), Color(0xFF1E2A4A)],
      [Color(0xFF2A1A1A), Color(0xFF4A2A1E)],
      [Color(0xFF1A2020), Color(0xFF1E3A3A)],
      [Color(0xFF201A2A), Color(0xFF3A1E4A)],
      [Color(0xFF2A2010), Color(0xFF4A3A10)],
    ];
    final idx = game.id.hashCode.abs() % palette.length;
    return palette[idx];
  }

  IconData get _icon {
    final icons = [
      Icons.terrain,
      Icons.castle,
      Icons.eco,
      Icons.factory,
      Icons.grain,
      Icons.train,
      Icons.medical_services,
      Icons.grid_4x4,
      Icons.diamond,
      Icons.account_balance,
      Icons.wine_bar,
      Icons.forest,
    ];
    return icons[game.id.hashCode.abs() % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        _icon,
        color: kColorPrimary.withAlpha(60),
        size: height * 0.4,
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final int winPercent;

  const _RarityBadge({required this.winPercent});

  String get _label {
    if (winPercent >= 70) return 'LEGENDARY';
    if (winPercent >= 50) return 'VETERAN';
    if (winPercent >= 30) return 'ADEPT';
    return 'NOVICE';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: kColorPrimary,
      child: Text(
        _label,
        style: GoogleFonts.spaceGrotesk(
          color: kColorOnPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final String category;

  const _CategoryChips({required this.category});

  @override
  Widget build(BuildContext context) {
    final parts = category.split(' · ');
    return Wrap(
      spacing: 6,
      children: parts
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1510),
                border: Border.all(color: kColorOutlineVariant),
              ),
              child: Text(
                p.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WinBar extends StatelessWidget {
  final double winRate;

  const _WinBar({required this.winRate});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1510),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: winRate.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayStats extends StatelessWidget {
  final GameStats stats;

  const _PlayStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${stats.wins}W',
          style: GoogleFonts.spaceGrotesk(
            color: kColorPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          ' / ${stats.totalPlays} plays',
          style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 10),
        ),
      ],
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: kColorPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color(0x1AF2CA50),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: kColorOnPrimary, size: 28),
      ),
    );
  }
}

class _PlaceholderGameScreen extends StatelessWidget {
  final GameStats stats;

  const _PlaceholderGameScreen({required this.stats});

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
          stats.game.name.toUpperCase(),
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
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction,
              color: kColorPrimary.withAlpha(80),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: GoogleFonts.newsreader(
                color: kColorOnSurfaceVariant,
                fontSize: 20,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
