import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_theme.dart';
import 'expedition_column.dart';

class LostCitiesCalculatorScreen extends StatefulWidget {
  const LostCitiesCalculatorScreen({super.key});

  @override
  State<LostCitiesCalculatorScreen> createState() =>
      _LostCitiesCalculatorScreenState();
}

class _LostCitiesCalculatorScreenState
    extends State<LostCitiesCalculatorScreen> {
  static const _expeditions = [
    (title: 'Gold', color: Color(0xFFF2CA50)),
    (title: 'Blue', color: Color(0xFF4A90E2)),
    (title: 'Purple', color: Color(0xFF9B59B6)),
    (title: 'Green', color: Color(0xFF50C878)),
    (title: 'Red', color: Color(0xFFE32636)),
  ];

  late final List<int> _scores;
  late final PageController _pageController;
  int _currentPage = 0;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _scores = List.filled(_expeditions.length, 0);
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
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: kColorPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'LOST CITIES',
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
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
                'RESET',
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
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
          child: Container(height: 1, color: kColorAmberBorder),
        ),
      ),
      body: Column(
        children: [
          // Page indicator dots
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_expeditions.length, (i) {
                final active = i == _currentPage;
                final color = _expeditions[i].color;
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
              itemCount: _expeditions.length,
              itemBuilder: (context, index) {
                final exp = _expeditions[index];
                return ExpeditionColumn(
                  key: ValueKey('$index-$_resetToken'),
                  title: exp.title,
                  color: exp.color,
                  onScoreChanged: (score) => _onScoreChanged(index, score),
                );
              },
            ),
          ),

          // Grand total bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0905),
              border: Border(top: BorderSide(color: kColorOutlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GRAND TOTAL',
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOnSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _grandTotal.toString(),
                  style: GoogleFonts.newsreader(
                    color: _grandTotal >= 0
                        ? kColorPrimary
                        : const Color(0xFFFF6B6B),
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
