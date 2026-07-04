import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/theme/app_theme.dart';

/// Horizontal row of selectable chips with a leading caption label.
class SelectorChipRow extends StatelessWidget {
  final String label;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SelectorChipRow({
    super.key,
    required this.label,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  _Chip(
                    label: labels[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kColorSurfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kColorPrimary : kColorOutlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: selected ? kColorPrimary : kColorOnSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Label + numeric entry field row, matching the 7 Wonders Duel styling.
class ScoreInputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool signed;

  const ScoreInputRow({
    super.key,
    required this.label,
    required this.controller,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(
              decimal: false,
              signed: signed,
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: kColorOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              hintStyle: GoogleFonts.newsreader(
                color: kColorOutline,
                fontSize: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 8,
              ),
              filled: true,
              fillColor: kColorSurfaceHigh,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kColorOutlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kColorPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom bar with the selected player's total and an optional result line.
class CalculatorTotalsBar extends StatelessWidget {
  final int total;
  final String totalLabel;
  final String? resultLabel;

  const CalculatorTotalsBar({
    super.key,
    required this.total,
    required this.totalLabel,
    this.resultLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: kColorAppBarBackground,
        border: Border(top: BorderSide(color: kColorOutlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              Text(
                total.toString(),
                style: GoogleFonts.newsreader(
                  color: kColorPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (resultLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              resultLabel!,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
