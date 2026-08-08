import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: claimed-route points plus completed destination
/// tickets, minus failed tickets, plus the +10 longest-route bonus (enter 1 for
/// the holder), plus 4 points per unused station.
int ticketToRideEuropeTotal({
  required int routes,
  required int ticketsDone,
  required int ticketsFailed,
  required int longest,
  required int stations,
}) {
  return routes + ticketsDone - ticketsFailed + longest * 10 + stations * 4;
}

/// Indices of the highest-scoring player(s). Ties are broken in-game by most
/// completed tickets (then longest route); tied players share the win here.
List<int> ticketToRideEuropeWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum TtreScoreCategory { routes, ticketsDone, ticketsFailed, longest, stations }

extension TtreScoreCategoryL10n on TtreScoreCategory {
  String label(AppStrings s) => switch (this) {
    TtreScoreCategory.routes => s.ttreRoutes,
    TtreScoreCategory.ticketsDone => s.ttreTicketsDone,
    TtreScoreCategory.ticketsFailed => s.ttreTicketsFailed,
    TtreScoreCategory.longest => s.ttreLongest,
    TtreScoreCategory.stations => s.ttreStations,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 5;

class TicketToRideEuropeCalculatorScreen extends StatefulWidget {
  const TicketToRideEuropeCalculatorScreen({super.key});

  @override
  State<TicketToRideEuropeCalculatorScreen> createState() =>
      _TicketToRideEuropeCalculatorScreenState();
}

class _TicketToRideEuropeCalculatorScreenState
    extends State<TicketToRideEuropeCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<TtreScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {for (final c in TtreScoreCategory.values) c: TextEditingController()},
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

  int _valueOf(int player, TtreScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => ticketToRideEuropeTotal(
    routes: _valueOf(player, TtreScoreCategory.routes),
    ticketsDone: _valueOf(player, TtreScoreCategory.ticketsDone),
    ticketsFailed: _valueOf(player, TtreScoreCategory.ticketsFailed),
    longest: _valueOf(player, TtreScoreCategory.longest),
    stations: _valueOf(player, TtreScoreCategory.stations),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = ticketToRideEuropeWinners(totals);
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
          s.ticketToRideEuropeTitle,
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
                  for (final category in TtreScoreCategory.values) ...[
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
