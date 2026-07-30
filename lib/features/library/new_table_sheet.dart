import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/campaign.dart';
import '../../shared/theme/app_colors.dart';
import '../plays/participant_picker_sheet.dart';

/// Collects the complete seat list for a new table.
///
/// A table's participants are fixed once it exists — every registered player
/// who should ever see this table has to be added here — so this sheet is the
/// only place membership is decided. Returns the seats, or null if cancelled.
Future<List<CampaignMember>?> showNewTableSheet(BuildContext context) =>
    showModalBottomSheet<List<CampaignMember>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NewTableSheet(),
    );

class _NewTableSheet extends StatefulWidget {
  const _NewTableSheet();

  @override
  State<_NewTableSheet> createState() => _NewTableSheetState();
}

class _NewTableSheetState extends State<_NewTableSheet> {
  late final List<CampaignMember> _seats;

  @override
  void initState() {
    super.initState();
    // The creator always holds the first seat. Firebase lookup mirrors the
    // pattern in addPlayProvider.
    String? name;
    String? uid;
    try {
      final user = FirebaseAuth.instance.currentUser;
      name = user?.displayName;
      uid = user?.uid;
    } catch (_) {}
    _seats = [
      CampaignMember(
        name: (name ?? '').trim().isEmpty ? 'You' : name!,
        userId: uid,
      ),
    ];
  }

  Set<String> get _addedUserIds => {
    for (final s in _seats)
      if (s.userId != null) s.userId!,
  };

  Future<void> _addPlayer() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // StatefulBuilder so the picker rebuilds as seats are added while it is
      // open: its "Added" marks are a pure function of addedUserIds, and the
      // picker sits on its own route, so this sheet's setState cannot reach it.
      // Without it a friend gets no feedback at all (guests self-flash "ADDED").
      builder: (_) => StatefulBuilder(
        builder: (context, setPickerState) => ParticipantPickerBottomSheet(
          addedUserIds: _addedUserIds,
          atMax: false,
          onAdd: (name, userId) {
            _seats.add(CampaignMember(name: name, userId: userId));
            setPickerState(() {}); // refresh the picker's "Added" marks
            setState(() {}); // refresh the seat list behind it
          },
        ),
      ),
    );
  }

  void _removeSeat(int index) => setState(() => _seats.removeAt(index));

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tableNewTitle,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.tableSeatsFinalHint,
            style: GoogleFonts.newsreader(
              color: context.colors.outline,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _seats.length; i++)
                    _SeatRow(
                      member: _seats[i],
                      // The creator's own seat cannot be given up.
                      onRemove: i == 0 ? null : () => _removeSeat(i),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addPlayer,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.tableAddPlayer),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_seats),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
              ),
              child: Text(s.tableCreate),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final CampaignMember member;
  final VoidCallback? onRemove;

  const _SeatRow({required this.member, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.name,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.onSurface,
                fontSize: 15,
              ),
            ),
          ),
          if (member.isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                s.tableGuestTag,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, color: context.colors.outline, size: 18),
            ),
        ],
      ),
    );
  }
}
