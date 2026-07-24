import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: a straight sum of all six categories.
/// Eggs, cached food, and tucked cards are 1 VP each, so counts equal VP.
int wingspanTotal({
  required int birds,
  required int bonusCards,
  required int roundGoals,
  required int eggs,
  required int cachedFood,
  required int tuckedCards,
}) {
  return birds + bonusCards + roundGoals + eggs + cachedFood + tuckedCards;
}

/// Indices of the highest-scoring player(s). Wingspan breaks ties by unused
/// food tokens, which this calculator does not track — tied players are all
/// returned and share the win.
List<int> wingspanWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum WingspanScoreCategory {
  birds,
  bonusCards,
  roundGoals,
  eggs,
  cachedFood,
  tuckedCards,
}

extension WingspanScoreCategoryL10n on WingspanScoreCategory {
  String label(AppStrings s) => switch (this) {
    WingspanScoreCategory.birds => s.wsBirds,
    WingspanScoreCategory.bonusCards => s.wsBonusCards,
    WingspanScoreCategory.roundGoals => s.wsRoundGoals,
    WingspanScoreCategory.eggs => s.wsEggs,
    WingspanScoreCategory.cachedFood => s.wsCachedFood,
    WingspanScoreCategory.tuckedCards => s.wsTuckedCards,
  };
}

const _kMinPlayers = 1;
const _kMaxPlayers = 5;

class WingspanCalculatorScreen extends StatefulWidget {
  const WingspanCalculatorScreen({super.key});

  @override
  State<WingspanCalculatorScreen> createState() =>
      _WingspanCalculatorScreenState();
}

class _WingspanCalculatorScreenState extends State<WingspanCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<WingspanScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in WingspanScoreCategory.values)
            c: TextEditingController(),
        },
    ];
    for (final player in _players) {
      for (final c in player.values) {
        c.addListener(_onChanged);
      }
    }
  }

  @override
  void dispose() {
    for (final player in _players) {
      for (final c in player.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _reset() {
    setState(() {
      for (final player in _players) {
        for (final c in player.values) {
          c.clear();
        }
      }
    });
  }

  int _valueOf(int player, WingspanScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => wingspanTotal(
    birds: _valueOf(player, WingspanScoreCategory.birds),
    bonusCards: _valueOf(player, WingspanScoreCategory.bonusCards),
    roundGoals: _valueOf(player, WingspanScoreCategory.roundGoals),
    eggs: _valueOf(player, WingspanScoreCategory.eggs),
    cachedFood: _valueOf(player, WingspanScoreCategory.cachedFood),
    tuckedCards: _valueOf(player, WingspanScoreCategory.tuckedCards),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = wingspanWinners(totals);
    if (winners.length == 1) return s.calcPlayerWins(winners.first + 1);
    return s.calcTieMulti(winners.map((i) => 'P${i + 1}').join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final totals = [for (var i = 0; i < _playerCount; i++) _totalOf(i)];

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
          s.wingspanTitle,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectorChipRow(
                  label: s.calcPlayers,
                  labels: [
                    for (var n = _kMinPlayers; n <= _kMaxPlayers; n++) '$n',
                  ],
                  selectedIndex: _playerCount - _kMinPlayers,
                  onSelected: (i) => setState(() {
                    _playerCount = _kMinPlayers + i;
                    _selected = math.min(_selected, _playerCount - 1);
                  }),
                ),
                const SizedBox(height: 8),
                SelectorChipRow(
                  label: s.calcShowing,
                  labels: [
                    for (var i = 0; i < _playerCount; i++)
                      s.calcPlayerChip(i + 1, totals[i]),
                  ],
                  selectedIndex: _selected,
                  onSelected: (i) => setState(() => _selected = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final category in WingspanScoreCategory.values) ...[
                    ScoreInputRow(
                      label: category.label(s),
                      controller: _players[_selected][category]!,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          CalculatorTotalsBar(
            total: totals[_selected],
            totalLabel: s.calcPlayerTotal(_selected + 1),
            resultLabel: _playerCount > 1 ? _winnerLabel(s, totals) : null,
          ),
        ],
      ),
    );
  }
}
