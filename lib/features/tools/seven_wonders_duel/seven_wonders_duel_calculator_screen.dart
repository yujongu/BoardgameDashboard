import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_theme.dart';
import 'score_row.dart';

/// Category VP plus floored coin VP for one player.
///
/// All inputs except [coins] are entered directly as victory points. [coins] is
/// a raw coin count contributing `coins ~/ 3` VP.
int sevenWondersGrandTotal({
  required int civilian,
  required int science,
  required int commercial,
  required int guilds,
  required int wonders,
  required int progress,
  required int military,
  required int coins,
}) {
  final categoryVP =
      civilian + science + commercial + guilds + wonders + progress + military;
  final coinVP = coins ~/ 3;
  return categoryVP + coinVP;
}

/// Grand total from a category map, treating any missing key as 0.
int sevenWondersTotalOf(Map<SevenWondersCategory, int> v) =>
    sevenWondersGrandTotal(
      civilian: v[SevenWondersCategory.civilian] ?? 0,
      science: v[SevenWondersCategory.science] ?? 0,
      commercial: v[SevenWondersCategory.commercial] ?? 0,
      guilds: v[SevenWondersCategory.guilds] ?? 0,
      wonders: v[SevenWondersCategory.wonders] ?? 0,
      progress: v[SevenWondersCategory.progress] ?? 0,
      military: v[SevenWondersCategory.military] ?? 0,
      coins: v[SevenWondersCategory.coins] ?? 0,
    );

enum SevenWondersWinner { player1, player2, tie }

class SevenWondersResult {
  final SevenWondersWinner winner;

  /// True when the winner was decided by the Civilian (Blue) VP tiebreaker
  /// rather than by grand total.
  final bool byTiebreaker;

  const SevenWondersResult({required this.winner, required this.byTiebreaker});
}

/// Determines the winner from both players' category maps.
///
/// Maps must contain every [SevenWondersCategory] key. Ties on grand total are
/// broken by higher Civilian (Blue) VP; a tie there too yields a
/// [SevenWondersWinner.tie] result.
SevenWondersResult sevenWondersResult({
  required Map<SevenWondersCategory, int> player1,
  required Map<SevenWondersCategory, int> player2,
}) {
  final t1 = sevenWondersTotalOf(player1);
  final t2 = sevenWondersTotalOf(player2);
  if (t1 > t2) {
    return const SevenWondersResult(
      winner: SevenWondersWinner.player1,
      byTiebreaker: false,
    );
  }
  if (t2 > t1) {
    return const SevenWondersResult(
      winner: SevenWondersWinner.player2,
      byTiebreaker: false,
    );
  }

  final c1 = player1[SevenWondersCategory.civilian] ?? 0;
  final c2 = player2[SevenWondersCategory.civilian] ?? 0;
  if (c1 > c2) {
    return const SevenWondersResult(
      winner: SevenWondersWinner.player1,
      byTiebreaker: true,
    );
  }
  if (c2 > c1) {
    return const SevenWondersResult(
      winner: SevenWondersWinner.player2,
      byTiebreaker: true,
    );
  }
  return const SevenWondersResult(
    winner: SevenWondersWinner.tie,
    byTiebreaker: false,
  );
}

class SevenWondersDuelCalculatorScreen extends StatefulWidget {
  const SevenWondersDuelCalculatorScreen({super.key});

  @override
  State<SevenWondersDuelCalculatorScreen> createState() =>
      _SevenWondersDuelCalculatorScreenState();
}

class _SevenWondersDuelCalculatorScreenState
    extends State<SevenWondersDuelCalculatorScreen> {
  late final Map<SevenWondersCategory, TextEditingController> _p1;
  late final Map<SevenWondersCategory, TextEditingController> _p2;

  @override
  void initState() {
    super.initState();
    _p1 = {
      for (final c in SevenWondersCategory.values) c: TextEditingController(),
    };
    _p2 = {
      for (final c in SevenWondersCategory.values) c: TextEditingController(),
    };
    for (final c in _p1.values) {
      c.addListener(_onChanged);
    }
    for (final c in _p2.values) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _p1.values) {
      c.dispose();
    }
    for (final c in _p2.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _reset() {
    setState(() {
      for (final c in _p1.values) {
        c.clear();
      }
      for (final c in _p2.values) {
        c.clear();
      }
    });
  }

  Map<SevenWondersCategory, int> _valuesOf(
    Map<SevenWondersCategory, TextEditingController> p,
  ) {
    return {
      for (final c in SevenWondersCategory.values)
        c: int.tryParse(p[c]!.text) ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final v1 = _valuesOf(_p1);
    final v2 = _valuesOf(_p2);
    final total1 = sevenWondersTotalOf(v1);
    final total2 = sevenWondersTotalOf(v2);
    final result = sevenWondersResult(player1: v1, player2: v2);

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: kColorAppBarBackground,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: kColorPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          '7 WONDERS DUEL',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScoreHeaderRow(),
                  const SizedBox(height: 8),
                  for (final category in SevenWondersCategory.values) ...[
                    ScoreRow(
                      category: category,
                      controller1: _p1[category]!,
                      controller2: _p2[category]!,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          _TotalsBar(total1: total1, total2: total2, result: result),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final int total1;
  final int total2;
  final SevenWondersResult result;

  const _TotalsBar({
    required this.total1,
    required this.total2,
    required this.result,
  });

  String get _winnerLabel {
    switch (result.winner) {
      case SevenWondersWinner.player1:
        return result.byTiebreaker
            ? 'PLAYER 1 WINS (TIEBREAKER)'
            : 'PLAYER 1 WINS';
      case SevenWondersWinner.player2:
        return result.byTiebreaker
            ? 'PLAYER 2 WINS (TIEBREAKER)'
            : 'PLAYER 2 WINS';
      case SevenWondersWinner.tie:
        return 'TIE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: kColorAppBarBackground,
        border: Border(top: BorderSide(color: kColorOutlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                total1.toString(),
                style: GoogleFonts.newsreader(
                  color: kColorPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'TOTAL',
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              Text(
                total2.toString(),
                style: GoogleFonts.newsreader(
                  color: kColorPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _winnerLabel,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
