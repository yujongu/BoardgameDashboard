import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

int calculateExpeditionScore(List<int> selectedNumbers, int handshakeCount) {
  if (selectedNumbers.isEmpty && handshakeCount == 0) return 0;

  int total = -20;
  for (int number in selectedNumbers) {
    total += number;
  }

  total *= (handshakeCount + 1);

  if (selectedNumbers.length >= 8) {
    total += 20;
  }

  return total;
}

class ExpeditionColumn extends StatefulWidget {
  final String title;
  final Color color;
  final Function(int) onScoreChanged;

  const ExpeditionColumn({
    super.key,
    required this.title,
    required this.color,
    required this.onScoreChanged,
  });

  @override
  State<ExpeditionColumn> createState() => _ExpeditionColumnState();
}

class _ExpeditionColumnState extends State<ExpeditionColumn>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Set<int> _selectedNumbers = {};
  int _handshakeCount = 0;
  int? _pressedHandshakeIndex;

  void _toggleNumber(int number) {
    setState(() {
      if (_selectedNumbers.contains(number)) {
        _selectedNumbers.remove(number);
      } else {
        _selectedNumbers.add(number);
      }
    });
    _updateScore();
  }

  void _toggleHandshake(int index) {
    setState(() {
      if (_handshakeCount == index + 1) {
        _handshakeCount = index;
      } else {
        _handshakeCount = index + 1;
      }
    });
    _updateScore();
  }

  void _updateScore() {
    final score = calculateExpeditionScore(
      _selectedNumbers.toList(),
      _handshakeCount,
    );
    widget.onScoreChanged(score);
  }

  int get _currentScore =>
      calculateExpeditionScore(_selectedNumbers.toList(), _handshakeCount);

  bool get _isStarted => _selectedNumbers.isNotEmpty || _handshakeCount > 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = AppStrings.of(context);
    final color = widget.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(25), const Color(0xFF1F1B13)],
        ),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: kColorOutlineVariant.withAlpha(80)),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.newsreader(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s.lostCitiesScorePrefix,
                        style: GoogleFonts.spaceGrotesk(
                          color: kColorOutline,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _isStarted ? _currentScore.toString() : s.scoreHint,
                        style: GoogleFonts.spaceGrotesk(
                          color: _isStarted
                              ? (_currentScore >= 0
                                    ? kColorOnSurface
                                    : const Color(0xFFFF6B6B))
                              : kColorOutline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  children: [
                    // Wager buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final active = index < _handshakeCount;
                        final pressed = _pressedHandshakeIndex == index;
                        return GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _pressedHandshakeIndex = index),
                          onTapUp: (_) {
                            setState(() => _pressedHandshakeIndex = null);
                            _toggleHandshake(index);
                          },
                          onTapCancel: () =>
                              setState(() => _pressedHandshakeIndex = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            width: 52,
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? color.withAlpha(pressed ? 45 : 25)
                                  : color.withAlpha(pressed ? 20 : 0),
                              border: Border.all(
                                color: active || pressed
                                    ? color
                                    : kColorOutlineVariant,
                                width: 1.5,
                              ),
                              boxShadow: active || pressed
                                  ? [
                                      BoxShadow(
                                        color: color.withAlpha(
                                          pressed ? 80 : 60,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.handshake,
                              color: active || pressed ? color : kColorOutline,
                              size: 22,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Number grid — 3 rows × 3 columns, each row Expanded so
                    // the grid fills remaining height without scrolling.
                    Expanded(
                      child: Column(
                        children: [
                          for (int row = 0; row < 3; row++) ...[
                            if (row > 0) const SizedBox(height: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  for (int col = 0; col < 3; col++) ...[
                                    if (col > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: _NumberButton(
                                        number: row * 3 + col + 2,
                                        color: color,
                                        isSelected: _selectedNumbers.contains(
                                          row * 3 + col + 2,
                                        ),
                                        onTap: () =>
                                            _toggleNumber(row * 3 + col + 2),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberButton extends StatefulWidget {
  final int number;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _NumberButton({
    required this.number,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<_NumberButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withAlpha(_pressed ? 170 : 220)
              : _pressed
              ? color.withAlpha(35)
              : const Color(0xFF1A1510),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected || _pressed ? color : kColorOutlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected || _pressed
              ? [
                  BoxShadow(
                    color: color.withAlpha(_pressed ? 100 : 70),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${widget.number}',
          style: GoogleFonts.newsreader(
            color: isSelected ? Colors.black87 : kColorOnSurface,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
