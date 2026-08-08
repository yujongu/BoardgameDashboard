import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

class ParticipantSearchField extends StatelessWidget {
  final TextEditingController controller;

  const ParticipantSearchField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: context.colors.outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.onSurface,
                  fontSize: 14,
                ).kr,
                decoration: InputDecoration.collapsed(
                  hintText: AppStrings.of(context).participantSearchHint,
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 14,
                  ).kr,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, child) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: controller.clear,
                      child: Icon(
                        Icons.close,
                        color: context.colors.outline,
                        size: 16,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
