import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: maki majority points, tempura/sashimi/dumpling
/// set points, nigiri (with wasabi) points, and the end-game pudding score,
/// which can be negative.
int sushiGoTotal({
  required int maki,
  required int tempuraSashimiDumpling,
  required int nigiri,
  required int puddings,
}) {
  return maki + tempuraSashimiDumpling + nigiri + puddings;
}

/// Indices of the highest-scoring player(s); tied players share the win.
List<int> sushiGoWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum SushiGoScoreCategory {
  maki,
  tempuraSashimiDumpling,
  nigiri,
  puddings(signed: true);

  const SushiGoScoreCategory({this.signed = false});

  final bool signed;
}

extension SushiGoScoreCategoryL10n on SushiGoScoreCategory {
  String label(AppStrings s) => switch (this) {
    SushiGoScoreCategory.maki => s.sgMaki,
    SushiGoScoreCategory.tempuraSashimiDumpling => s.sgTsd,
    SushiGoScoreCategory.nigiri => s.sgNigiri,
    SushiGoScoreCategory.puddings => s.sgPudding,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 5;

class SushiGoCalculatorScreen extends StatefulWidget {
  const SushiGoCalculatorScreen({super.key});

  @override
  State<SushiGoCalculatorScreen> createState() =>
      _SushiGoCalculatorScreenState();
}

class _SushiGoCalculatorScreenState extends State<SushiGoCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<SushiGoScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in SushiGoScoreCategory.values)
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

  int _valueOf(int player, SushiGoScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => sushiGoTotal(
    maki: _valueOf(player, SushiGoScoreCategory.maki),
    tempuraSashimiDumpling: _valueOf(
      player,
      SushiGoScoreCategory.tempuraSashimiDumpling,
    ),
    nigiri: _valueOf(player, SushiGoScoreCategory.nigiri),
    puddings: _valueOf(player, SushiGoScoreCategory.puddings),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = sushiGoWinners(totals);
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
          s.sushiGoTitle,
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
                  for (final category in SushiGoScoreCategory.values) ...[
                    ScoreInputRow(
                      label: category.label(s),
                      controller: _players[_selected][category]!,
                      signed: category.signed,
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
