import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import 'add_play_notifier.dart';
import 'participant_list_section.dart';
import 'participant_picker_controller.dart';
import 'participant_search_section.dart';

class ParticipantPickerBottomSheet extends ConsumerStatefulWidget {
  final void Function(String name, String? userId) onAdd;

  const ParticipantPickerBottomSheet({super.key, required this.onAdd});

  @override
  ConsumerState<ParticipantPickerBottomSheet> createState() =>
      _ParticipantPickerBottomSheetState();
}

class _ParticipantPickerBottomSheetState
    extends ConsumerState<ParticipantPickerBottomSheet> {
  final _searchController = TextEditingController();
  String? _addedGuestName;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref
          .read(participantPickerProvider.notifier)
          .setQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onAdd(String name, String? userId) {
    widget.onAdd(name, userId);
    if (userId == null) {
      _searchController.clear();
      _resetTimer?.cancel();
      setState(() => _addedGuestName = name);
      _resetTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _addedGuestName = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final atMax = !ref.watch(addPlayProvider).canAddParticipant;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            _handle(),
            _sheetTitle(),
            Container(height: 1, color: kColorAmberBorder),
            ParticipantSearchField(controller: _searchController),
            if (atMax)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  AppStrings.of(context).participantMaxReached,
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            Expanded(child: ParticipantListSection(onAdd: _onAdd)),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: kColorOutlineVariant,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sheetTitle() {
    final s = AppStrings.of(context);
    final guestName = _addedGuestName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        guestName != null
            ? s.participantGuestAdded(guestName)
            : s.participantAddTitle,
        style: GoogleFonts.spaceGrotesk(
          color: guestName != null ? kColorPrimary : kColorOutline,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
