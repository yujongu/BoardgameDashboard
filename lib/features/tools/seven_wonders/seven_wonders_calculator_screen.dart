import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Science (Green) VP: each symbol type scores count squared, plus 7 VP per
/// complete set of the three different symbols.
int sevenWondersScienceScore({
  required int tablets,
  required int compasses,
  required int gears,
}) {
  final sets = math.min(tablets, math.min(compasses, gears));
  return tablets * tablets + compasses * compasses + gears * gears + 7 * sets;
}

/// Grand total for one player. [military] is the net conflict-token VP and may
/// be negative. [coins] is a raw coin count contributing `coins ~/ 3` VP.
/// Science symbols are entered as counts and scored via
/// [sevenWondersScienceScore].
int sevenWondersClassicTotal({
  required int military,
  required int coins,
  required int wonders,
  required int civilian,
  required int commercial,
  required int guilds,
  required int tablets,
  required int compasses,
  required int gears,
}) {
  return military +
      coins ~/ 3 +
      wonders +
      civilian +
      commercial +
      guilds +
      sevenWondersScienceScore(
        tablets: tablets,
        compasses: compasses,
        gears: gears,
      );
}

/// Indices of the winning player(s): highest total, ties broken by most
/// coins; players still tied after that share the victory.
List<int> sevenWondersClassicWinners({
  required List<int> totals,
  required List<int> coins,
}) {
  assert(totals.length == coins.length);
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  final tied = [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
  if (tied.length == 1) return tied;
  final maxCoins = tied.map((i) => coins[i]).reduce(math.max);
  return [
    for (final i in tied)
      if (coins[i] == maxCoins) i,
  ];
}

enum SevenWondersScoreCategory {
  military(signed: true),
  coins,
  wonders,
  civilian,
  commercial,
  guilds,
  tablets,
  compasses,
  gears;

  const SevenWondersScoreCategory({this.signed = false});

  final bool signed;
}

extension SevenWondersScoreCategoryL10n on SevenWondersScoreCategory {
  String label(AppStrings s) => switch (this) {
    SevenWondersScoreCategory.military => s.sw7Military,
    SevenWondersScoreCategory.coins => s.swCoins,
    SevenWondersScoreCategory.wonders => s.sw7Wonders,
    SevenWondersScoreCategory.civilian => s.swCivilian,
    SevenWondersScoreCategory.commercial => s.swCommercial,
    SevenWondersScoreCategory.guilds => s.swGuilds,
    SevenWondersScoreCategory.tablets => s.sw7Tablets,
    SevenWondersScoreCategory.compasses => s.sw7Compasses,
    SevenWondersScoreCategory.gears => s.sw7Gears,
  };
}

const _kMinPlayers = 3;
const _kMaxPlayers = 7;

class SevenWondersCalculatorScreen extends StatefulWidget {
  const SevenWondersCalculatorScreen({super.key});

  @override
  State<SevenWondersCalculatorScreen> createState() =>
      _SevenWondersCalculatorScreenState();
}

class _SevenWondersCalculatorScreenState
    extends State<SevenWondersCalculatorScreen> {
  int _playerCount = _kMinPlayers;
  int _selected = 0;
  late final List<Map<SevenWondersScoreCategory, TextEditingController>>
  _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in SevenWondersScoreCategory.values)
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

  int _valueOf(int player, SevenWondersScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => sevenWondersClassicTotal(
    military: _valueOf(player, SevenWondersScoreCategory.military),
    coins: _valueOf(player, SevenWondersScoreCategory.coins),
    wonders: _valueOf(player, SevenWondersScoreCategory.wonders),
    civilian: _valueOf(player, SevenWondersScoreCategory.civilian),
    commercial: _valueOf(player, SevenWondersScoreCategory.commercial),
    guilds: _valueOf(player, SevenWondersScoreCategory.guilds),
    tablets: _valueOf(player, SevenWondersScoreCategory.tablets),
    compasses: _valueOf(player, SevenWondersScoreCategory.compasses),
    gears: _valueOf(player, SevenWondersScoreCategory.gears),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = sevenWondersClassicWinners(
      totals: totals,
      coins: [
        for (var i = 0; i < _playerCount; i++)
          _valueOf(i, SevenWondersScoreCategory.coins),
      ],
    );
    if (winners.length == 1) return s.calcPlayerWins(winners.first + 1);
    return s.calcTieMulti(winners.map((i) => 'P${i + 1}').join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final totals = [for (var i = 0; i < _playerCount; i++) _totalOf(i)];
    final scienceVp = sevenWondersScienceScore(
      tablets: _valueOf(_selected, SevenWondersScoreCategory.tablets),
      compasses: _valueOf(_selected, SevenWondersScoreCategory.compasses),
      gears: _valueOf(_selected, SevenWondersScoreCategory.gears),
    );

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
          s.sevenWondersTitle,
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
                  for (final category in SevenWondersScoreCategory.values) ...[
                    if (category == SevenWondersScoreCategory.tablets)
                      _SectionHeader(
                        label: s.sevenWondersScienceHeader(scienceVp),
                      ),
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
            resultLabel: _winnerLabel(s, totals),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
