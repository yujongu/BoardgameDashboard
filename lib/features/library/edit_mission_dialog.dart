import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

/// Result of [EditMissionDialog]: the corrected tries count and passed flag.
class MissionEdit {
  final int tries;
  final bool passed;
  const MissionEdit(this.tries, this.passed);
}

/// Corrects one stage's recorded tries and passed status.
///
/// Shared by the Add-Play mission record and the Game Detail board card. The
/// board card needs it because campaign progress deliberately *latches*: logging
/// a won mission marks it complete, and deleting that play does not rewind the
/// board — a mission the team genuinely beat should stay beaten even if the play
/// record is tidied up. This dialog is the undo path for the cases where that
/// isn't what happened.
class EditMissionDialog extends StatefulWidget {
  /// Localised name for one stage ("Mission", "Scenario", …).
  final String axis;
  final int stage;
  final int initialTries;
  final bool initialPassed;

  const EditMissionDialog({
    super.key,
    required this.axis,
    required this.stage,
    required this.initialTries,
    required this.initialPassed,
  });

  @override
  State<EditMissionDialog> createState() => _EditMissionDialogState();
}

class _EditMissionDialogState extends State<EditMissionDialog> {
  late final TextEditingController _tries = TextEditingController(
    text: '${widget.initialTries}',
  );
  late bool _passed = widget.initialPassed;

  @override
  void dispose() {
    _tries.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_tries.text.trim()) ?? widget.initialTries;
    Navigator.of(context).pop(MissionEdit(n < 0 ? 0 : n, _passed));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      backgroundColor: context.colors.surfaceHigh,
      title: Text(
        '${s.crewEditMissionTitle} · ${s.stageLabelNumbered(widget.axis, widget.stage)}',
        style: GoogleFonts.newsreader(
          color: context.colors.onSurface,
          fontSize: 18,
        ).kr,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _tries,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.onSurface,
              fontSize: 15,
            ).kr,
            decoration: InputDecoration(
              labelText: s.crewTriesLabel,
              labelStyle: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 13,
              ).kr,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.outlineVariant),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.primary),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.crewMissionPassed,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.onSurface,
                  fontSize: 14,
                ).kr,
              ),
              Switch(
                value: _passed,
                activeThumbColor: context.colors.primary,
                onChanged: (v) => setState(() => _passed = v),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            s.commonCancelCaps,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ).kr,
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            s.commonOk,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ).kr,
          ),
        ),
      ],
    );
  }
}
