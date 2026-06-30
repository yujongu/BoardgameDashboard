import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_theme.dart';

enum SevenWondersCategory {
  civilian('Civilian (Blue) VP'),
  science('Science (Green) VP'),
  commercial('Commercial (Yellow) VP'),
  guilds('Guilds (Purple) VP'),
  wonders('Wonders VP'),
  progress('Progress tokens VP'),
  military('Military tokens VP'),
  coins('Coins (÷3 → VP)');

  const SevenWondersCategory(this.label);

  final String label;
}

class ScoreHeaderRow extends StatelessWidget {
  const ScoreHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.spaceGrotesk(
      color: kColorOnSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
    return Row(
      children: [
        Expanded(flex: 4, child: Text('CATEGORY', style: style)),
        Expanded(
          flex: 3,
          child: Text('PLAYER 1', textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text('PLAYER 2', textAlign: TextAlign.center, style: style),
        ),
      ],
    );
  }
}

class ScoreRow extends StatelessWidget {
  final SevenWondersCategory category;
  final TextEditingController controller1;
  final TextEditingController controller2;

  const ScoreRow({
    super.key,
    required this.category,
    required this.controller1,
    required this.controller2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            category.label,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(flex: 3, child: _ScoreField(controller: controller1)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _ScoreField(controller: controller2)),
      ],
    );
  }
}

class _ScoreField extends StatelessWidget {
  final TextEditingController controller;

  const _ScoreField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      textAlign: TextAlign.center,
      style: GoogleFonts.newsreader(
        color: kColorOnSurface,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: GoogleFonts.newsreader(color: kColorOutline, fontSize: 18),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
    );
  }
}
