import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

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
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: kColorOutline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: AppStrings.of(context).participantSearchHint,
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, child) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: controller.clear,
                      child: const Icon(
                        Icons.close,
                        color: kColorOutline,
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
