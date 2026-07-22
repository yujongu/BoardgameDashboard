import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/models/game_tool.dart';

class ToolCard extends StatelessWidget {
  final GameTool tool;

  const ToolCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Material(
      color: kColorSurfaceHigh,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: tool.destinationBuilder)),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: kColorAmberBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kColorSurface,
                  border: Border.all(color: kColorOutlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(tool.icon, color: kColorPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title(s),
                      style: GoogleFonts.newsreader(
                        color: kColorOnSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.description(s),
                      style: GoogleFonts.spaceGrotesk(
                        color: kColorOutline,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: kColorOutlineVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
