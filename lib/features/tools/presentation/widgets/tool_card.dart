import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_fonts.dart';
import '../../domain/models/game_tool.dart';

class ToolCard extends StatelessWidget {
  final GameTool tool;

  const ToolCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Material(
      color: context.colors.surfaceHigh,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: tool.destinationBuilder)),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.amberBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(tool.icon, color: context.colors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title(s),
                      style: GoogleFonts.newsreader(
                        color: context.colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ).kr,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.description(s),
                      style: GoogleFonts.spaceGrotesk(
                        color: context.colors.outline,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ).kr,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
