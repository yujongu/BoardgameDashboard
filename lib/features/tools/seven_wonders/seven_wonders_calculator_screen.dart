import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/theme/app_theme.dart';
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
  military('Military tokens (net VP)', signed: true),
  coins('Coins (÷3 → VP)'),
  wonders('Wonder stages VP'),
  civilian('Civilian (Blue) VP'),
  commercial('Commercial (Yellow) VP'),
  guilds('Guilds (Purple) VP'),
  tablets('Tablets'),
  compasses('Compasses'),
  gears('Gears');

  const SevenWondersScoreCategory(this.label, {this.signed = false});

  final String label;
  final bool signed;
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

  String _winnerLabel(List<int> totals) {
    final winners = sevenWondersClassicWinners(
      totals: totals,
      coins: [
        for (var i = 0; i < _playerCount; i++)
          _valueOf(i, SevenWondersScoreCategory.coins),
      ],
    );
    if (winners.length == 1) return 'PLAYER ${winners.first + 1} WINS';
    return 'TIE: ${winners.map((i) => 'P${i + 1}').join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final totals = [for (var i = 0; i < _playerCount; i++) _totalOf(i)];
    final scienceVp = sevenWondersScienceScore(
      tablets: _valueOf(_selected, SevenWondersScoreCategory.tablets),
      compasses: _valueOf(_selected, SevenWondersScoreCategory.compasses),
      gears: _valueOf(_selected, SevenWondersScoreCategory.gears),
    );

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
          '7 WONDERS',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectorChipRow(
                  label: 'PLAYERS',
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
                  label: 'SHOWING',
                  labels: [
                    for (var i = 0; i < _playerCount; i++)
                      'P${i + 1} · ${totals[i]}',
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
                      _SectionHeader(label: 'SCIENCE (GREEN) — $scienceVp VP'),
                    ScoreInputRow(
                      label: category.label,
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
            totalLabel: 'P${_selected + 1} TOTAL',
            resultLabel: _winnerLabel(totals),
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
          color: kColorOnSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
