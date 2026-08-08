import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';
import '../presentation/widgets/calculator_widgets.dart';

/// Score for one player: in Tigris & Euphrates a player's score is the number
/// of treasures in their *weakest* colour, so the total is the minimum of the
/// four colour counts.
int tigrisEuphratesTotal({
  required int red,
  required int blue,
  required int green,
  required int black,
}) {
  return math.min(math.min(red, blue), math.min(green, black));
}

/// Indices of the highest-scoring player(s) — the highest weakest-colour count.
/// The in-game tiebreak compares each player's next-weakest colour, which this
/// calculator does not apply — tied players share the win.
List<int> tigrisEuphratesWinners(List<int> totals) {
  if (totals.isEmpty) return const [];
  final maxTotal = totals.reduce(math.max);
  return [
    for (var i = 0; i < totals.length; i++)
      if (totals[i] == maxTotal) i,
  ];
}

enum TigrisScoreCategory { red, blue, green, black }

extension TigrisScoreCategoryL10n on TigrisScoreCategory {
  String label(AppStrings s) => switch (this) {
    TigrisScoreCategory.red => s.teRed,
    TigrisScoreCategory.blue => s.teBlue,
    TigrisScoreCategory.green => s.teGreen,
    TigrisScoreCategory.black => s.teBlack,
  };
}

const _kMinPlayers = 2;
const _kMaxPlayers = 4;

class TigrisAndEuphratesCalculatorScreen extends StatefulWidget {
  const TigrisAndEuphratesCalculatorScreen({super.key});

  @override
  State<TigrisAndEuphratesCalculatorScreen> createState() =>
      _TigrisAndEuphratesCalculatorScreenState();
}

class _TigrisAndEuphratesCalculatorScreenState
    extends State<TigrisAndEuphratesCalculatorScreen> {
  int _playerCount = 2;
  int _selected = 0;
  late final List<Map<TigrisScoreCategory, TextEditingController>> _players;

  @override
  void initState() {
    super.initState();
    _players = [
      for (var i = 0; i < _kMaxPlayers; i++)
        {
          for (final c in TigrisScoreCategory.values)
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

  int _valueOf(int player, TigrisScoreCategory c) =>
      int.tryParse(_players[player][c]!.text) ?? 0;

  int _totalOf(int player) => tigrisEuphratesTotal(
    red: _valueOf(player, TigrisScoreCategory.red),
    blue: _valueOf(player, TigrisScoreCategory.blue),
    green: _valueOf(player, TigrisScoreCategory.green),
    black: _valueOf(player, TigrisScoreCategory.black),
  );

  String _winnerLabel(AppStrings s, List<int> totals) {
    final winners = tigrisEuphratesWinners(totals);
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
          s.tigrisAndEuphratesTitle,
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
                  _SectionHeader(label: s.tigrisScoreHeader(totals[_selected])),
                  for (final category in TigrisScoreCategory.values) ...[
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

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ).kr,
      ),
    );
  }
}
