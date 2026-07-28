import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: buttons (money) plus the +7 special 7×7 tile
/// (enter 1 if held), minus 2 points per empty square on the quilt board.
int patchworkTotal({
  required int buttons,
  required int special7x7,
  required int emptySpaces,
}) {
  return buttons + special7x7 * 7 - emptySpaces * 2;
}

/// Indices of the highest-scoring player(s). Patchwork breaks ties in favour of
/// the player who took the final turn, which this calculator does not track —
/// tied players share the win.
List<int> patchworkWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum PatchworkScoreCategory { buttons, special7x7, emptySpaces }

extension PatchworkScoreCategoryL10n on PatchworkScoreCategory {
  String label(AppStrings s) => switch (this) {
    PatchworkScoreCategory.buttons => s.pwButtons,
    PatchworkScoreCategory.special7x7 => s.pwSpecial,
    PatchworkScoreCategory.emptySpaces => s.pwEmpty,
  };
}

const _kMaxPlayers = 2;

class PatchworkCalculatorScreen extends StatefulWidget {
  const PatchworkCalculatorScreen({super.key});

  @override
  State<PatchworkCalculatorScreen> createState() =>
      _PatchworkCalculatorScreenState();
}

class _PatchworkCalculatorScreenState extends State<PatchworkCalculatorScreen> {
  final int _playerCount = 2;
  int _selected = 0;
  late final List<Map<PatchworkScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in PatchworkScoreCategory.values)
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

  int _valueOf(int player, PatchworkScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => patchworkTotal(
    buttons: _valueOf(player, PatchworkScoreCategory.buttons),
    special7x7: _valueOf(player, PatchworkScoreCategory.special7x7),
    emptySpaces: _valueOf(player, PatchworkScoreCategory.emptySpaces),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = patchworkWinners(totals);
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
          s.patchworkTitle,
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
                  for (final category in PatchworkScoreCategory.values) ...[
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
            resultLabel: _winnerLabel(s, totals),
          ),
        ],
      ),
    );
  }
}
