import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Grand total for one player: claimed-route points plus completed destination
/// tickets, minus failed tickets, plus the +10 longest-route bonus (enter 1 for
/// the player who holds it).
int ticketToRideTotal({
  required int routes,
  required int ticketsDone,
  required int ticketsFailed,
  required int longest,
}) {
  return routes + ticketsDone - ticketsFailed + longest * 10;
}

/// Indices of the highest-scoring player(s). Ticket to Ride breaks ties by most
/// completed tickets (then longest route), which this calculator does not
/// apply — tied players share the win.
List<int> ticketToRideWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum TtrScoreCategory { routes, ticketsDone, ticketsFailed, longest }

extension TtrScoreCategoryL10n on TtrScoreCategory {
  String label(AppStrings s) => switch (this) {
    TtrScoreCategory.routes => s.ttrRoutes,
    TtrScoreCategory.ticketsDone => s.ttrTicketsDone,
    TtrScoreCategory.ticketsFailed => s.ttrTicketsFailed,
    TtrScoreCategory.longest => s.ttrLongest,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 5;

class TicketToRideCalculatorScreen extends StatefulWidget {
  const TicketToRideCalculatorScreen({super.key});

  @override
  State<TicketToRideCalculatorScreen> createState() =>
      _TicketToRideCalculatorScreenState();
}

class _TicketToRideCalculatorScreenState
    extends State<TicketToRideCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<TtrScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {for (final c in TtrScoreCategory.values) c: TextEditingController()},
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

  int _valueOf(int player, TtrScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => ticketToRideTotal(
    routes: _valueOf(player, TtrScoreCategory.routes),
    ticketsDone: _valueOf(player, TtrScoreCategory.ticketsDone),
    ticketsFailed: _valueOf(player, TtrScoreCategory.ticketsFailed),
    longest: _valueOf(player, TtrScoreCategory.longest),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = ticketToRideWinners(totals);
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
          s.ticketToRideTitle,
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
                  for (final category in TtrScoreCategory.values) ...[
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
