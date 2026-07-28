import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: nigiri, roll (maki/temaki), appetizer, and
/// special points, plus the end-game dessert score, which can be negative.
int sushiGoPartyTotal({
  required int nigiri,
  required int rolls,
  required int appetizers,
  required int specials,
  required int desserts,
}) {
  return nigiri + rolls + appetizers + specials + desserts;
}

/// Indices of the highest-scoring player(s); tied players share the win.
List<int> sushiGoPartyWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum SushiGoPartyScoreCategory {
  nigiri,
  rolls,
  appetizers,
  specials,
  desserts(signed: true);

  const SushiGoPartyScoreCategory({this.signed = false});

  final bool signed;
}

extension SushiGoPartyScoreCategoryL10n on SushiGoPartyScoreCategory {
  String label(AppStrings s) => switch (this) {
    SushiGoPartyScoreCategory.nigiri => s.sgpNigiri,
    SushiGoPartyScoreCategory.rolls => s.sgpRolls,
    SushiGoPartyScoreCategory.appetizers => s.sgpAppetizers,
    SushiGoPartyScoreCategory.specials => s.sgpSpecials,
    SushiGoPartyScoreCategory.desserts => s.sgpDesserts,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 8;

class SushiGoPartyCalculatorScreen extends StatefulWidget {
  const SushiGoPartyCalculatorScreen({super.key});

  @override
  State<SushiGoPartyCalculatorScreen> createState() =>
      _SushiGoPartyCalculatorScreenState();
}

class _SushiGoPartyCalculatorScreenState
    extends State<SushiGoPartyCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<SushiGoPartyScoreCategory, TextEditingController>>
  _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in SushiGoPartyScoreCategory.values)
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

  int _valueOf(int player, SushiGoPartyScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => sushiGoPartyTotal(
    nigiri: _valueOf(player, SushiGoPartyScoreCategory.nigiri),
    rolls: _valueOf(player, SushiGoPartyScoreCategory.rolls),
    appetizers: _valueOf(player, SushiGoPartyScoreCategory.appetizers),
    specials: _valueOf(player, SushiGoPartyScoreCategory.specials),
    desserts: _valueOf(player, SushiGoPartyScoreCategory.desserts),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = sushiGoPartyWinners(totals);
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
          s.sushiGoPartyTitle,
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
                  for (final category in SushiGoPartyScoreCategory.values) ...[
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
