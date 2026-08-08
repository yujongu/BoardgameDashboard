import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: −1 point per square left in unplaced pieces,
/// +15 if every piece was placed (enter 1), and a further +5 if the last piece
/// placed was the single-square piece (enter 1). Scores are often negative.
int blokusTotal({
  required int remaining,
  required int allPlaced,
  required int monomino,
}) {
  return allPlaced * 15 + monomino * 5 - remaining;
}

/// Indices of the highest-scoring player(s); tied players share the win.
List<int> blokusWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum BlokusScoreCategory { remaining, allPlaced, monomino }

extension BlokusScoreCategoryL10n on BlokusScoreCategory {
  String label(AppStrings s) => switch (this) {
    BlokusScoreCategory.remaining => s.bloRemaining,
    BlokusScoreCategory.allPlaced => s.bloAllPlaced,
    BlokusScoreCategory.monomino => s.bloMonomino,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 4;

class BlokusCalculatorScreen extends StatefulWidget {
  const BlokusCalculatorScreen({super.key});

  @override
  State<BlokusCalculatorScreen> createState() => _BlokusCalculatorScreenState();
}

class _BlokusCalculatorScreenState extends State<BlokusCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<BlokusScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in BlokusScoreCategory.values)
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

  int _valueOf(int player, BlokusScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => blokusTotal(
    remaining: _valueOf(player, BlokusScoreCategory.remaining),
    allPlaced: _valueOf(player, BlokusScoreCategory.allPlaced),
    monomino: _valueOf(player, BlokusScoreCategory.monomino),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = blokusWinners(totals);
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
          s.blokusTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
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
                ).kr,
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
                  for (final category in BlokusScoreCategory.values) ...[
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
