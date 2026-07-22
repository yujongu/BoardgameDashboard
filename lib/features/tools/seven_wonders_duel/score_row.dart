import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

enum SevenWondersCategory {
  civilian,
  science,
  commercial,
  guilds,
  wonders,
  progress,
  military,
  coins,
}

extension SevenWondersCategoryL10n on SevenWondersCategory {
  String label(AppStrings s) => switch (this) {
    SevenWondersCategory.civilian => s.swCivilian,
    SevenWondersCategory.science => s.swScience,
    SevenWondersCategory.commercial => s.swCommercial,
    SevenWondersCategory.guilds => s.swGuilds,
    SevenWondersCategory.wonders => s.sw7dWonders,
    SevenWondersCategory.progress => s.sw7dProgress,
    SevenWondersCategory.military => s.sw7dMilitary,
    SevenWondersCategory.coins => s.swCoins,
  };
}

class ScoreHeaderRow extends StatelessWidget {
  const ScoreHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final style = GoogleFonts.spaceGrotesk(
      color: kColorOnSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
    return Row(
      children: [
        Expanded(flex: 4, child: Text(s.calcCategory, style: style)),
        Expanded(
          flex: 3,
          child: Text(s.calcPlayer1, textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text(s.calcPlayer2, textAlign: TextAlign.center, style: style),
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
            category.label(AppStrings.of(context)),
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
