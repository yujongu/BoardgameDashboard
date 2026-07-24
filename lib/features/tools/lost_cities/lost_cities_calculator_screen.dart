import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import 'expedition_column.dart';

class LostCitiesCalculatorScreen extends StatefulWidget {
  const LostCitiesCalculatorScreen({super.key});

  @override
  State<LostCitiesCalculatorScreen> createState() =>
      _LostCitiesCalculatorScreenState();
}

class _LostCitiesCalculatorScreenState
    extends State<LostCitiesCalculatorScreen> {
  static const _expeditionColors = [
    Color(0xFFF2CA50),
    Color(0xFF4A90E2),
    Color(0xFF9B59B6),
    Color(0xFF50C878),
    Color(0xFFE32636),
  ];

  // Same five suits deepened for the light theme — the bright versions drop to
  // ~1.7:1 against the paper background as titles, borders and dot indicators.
  static const _expeditionColorsLight = [
    Color(0xFF7A5E0A),
    Color(0xFF1F4E8C),
    Color(0xFF5B2C72),
    Color(0xFF1F6B45),
    Color(0xFF9B1721),
  ];

  late final List<int> _scores;
  late final PageController _pageController;
  int _currentPage = 0;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _scores = List.filled(_expeditionColors.length, 0);
    _pageController = PageController(viewportFraction: 0.88)
      ..addListener(() {
        final page = _pageController.page?.round() ?? 0;
        if (page != _currentPage) setState(() => _currentPage = page);
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onScoreChanged(int index, int score) {
    setState(() => _scores[index] = score);
  }

  void _reset() {
    setState(() {
      _resetToken++;
      for (int i = 0; i < _scores.length; i++) {
        _scores[i] = 0;
      }
    });
  }

  int get _grandTotal => _scores.fold(0, (sum, s) => sum + s);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final expeditionColors = Theme.of(context).brightness == Brightness.dark
        ? _expeditionColors
        : _expeditionColorsLight;
    final titles = [
      s.lostCitiesGold,
      s.lostCitiesBlue,
      s.lostCitiesPurple,
      s.lostCitiesGreen,
      s.lostCitiesRed,
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          s.lostCitiesTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _reset,
              child: Text(
                s.calcReset,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: Column(
        children: [
          // Page indicator dots
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(expeditionColors.length, (i) {
                final active = i == _currentPage;
                final color = expeditionColors[i];
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? color : color.withAlpha(70),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Horizontal swipeable expedition columns
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const _HighThresholdScrollPhysics(),
              itemCount: expeditionColors.length,
              itemBuilder: (context, index) {
                return ExpeditionColumn(
                  key: ValueKey('$index-$_resetToken'),
                  title: titles[index],
                  color: expeditionColors[index],
                  onScoreChanged: (score) => _onScoreChanged(index, score),
                );
              },
            ),
          ),

          // Grand total bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.appBarBackground,
              border: Border(
                top: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.calcGrandTotal,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _grandTotal.toString(),
                  style: GoogleFonts.newsreader(
                    color: _grandTotal >= 0
                        ? context.colors.primary
                        : Theme.of(context).colorScheme.error,
                    fontSize: 38,
                    fontWeight: FontWeight.w600,
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

class _HighThresholdScrollPhysics extends ScrollPhysics {
  const _HighThresholdScrollPhysics({super.parent});

  @override
  _HighThresholdScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _HighThresholdScrollPhysics(parent: buildParent(ancestor));

  @override
  double get dragStartDistanceMotionThreshold => 20.0;

  // Stiffer spring (400 vs default 100) with critical damping so the page
  // snaps to its final position ~4x faster, freeing tap events sooner.
  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 400.0);
}
