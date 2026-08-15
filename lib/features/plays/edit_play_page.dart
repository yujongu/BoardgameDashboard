import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/play.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../../shared/widgets/game_picker_sheet.dart';
import 'participant_picker_sheet.dart';

// ─── Player entry (local state holder) ───────────────────────────────────────

class _PlayerEntry {
  _PlayerEntry({this.userId, double? score}) {
    if (score != null) scoreController.text = _formatScore(score);
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController scoreController = TextEditingController();
  bool isWinner = false;
  final String? userId;

  double? get score => double.tryParse(scoreController.text.trim());

  void dispose() {
    nameController.dispose();
    scoreController.dispose();
  }
}

/// Renders a score as an int when whole (12 not 12.0), else with its decimals.
String _formatScore(double score) => score == score.truncateToDouble()
    ? score.toInt().toString()
    : score.toString();

// ─── Screen ───────────────────────────────────────────────────────────────────

class EditPlayPage extends StatefulWidget {
  final PlayDetail detail;

  const EditPlayPage({super.key, required this.detail});

  @override
  State<EditPlayPage> createState() => _EditPlayPageState();
}

class _EditPlayPageState extends State<EditPlayPage> {
  late String _gameId;
  late String _gameName;
  late DateTime _playedAt;
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_PlayerEntry> _players = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _gameId = widget.detail.gameId;
    _gameName = widget.detail.gameName;
    _playedAt = widget.detail.playedAt.toLocal();
    _locationController.text = widget.detail.location ?? '';
    _notesController.text = widget.detail.notes ?? '';

    for (final p in widget.detail.participants) {
      final entry = _PlayerEntry(userId: p.userId, score: p.score);
      entry.nameController.text = p.name;
      entry.isWinner = p.isWinner;
      entry.nameController.addListener(() => setState(() {}));
      _players.add(entry);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _players.isNotEmpty &&
      _players.any((p) => p.nameController.text.trim().isNotEmpty) &&
      _players.any(
        (p) => p.isWinner && p.nameController.text.trim().isNotEmpty,
      );

  Future<void> _showGamePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GamePickerSheet(
        onSelect: (game) {
          setState(() {
            _gameId = game.gameId;
            _gameName = game.name;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _playedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: context.colors.primary,
            onPrimary: context.colors.onPrimary,
            surface: context.colors.surface,
            onSurface: context.colors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _playedAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _playedAt.hour,
          _playedAt.minute,
          _playedAt.second,
        );
      });
    }
  }

  Future<void> _showParticipantPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // StatefulBuilder so the sheet re-renders as players are added while it
      // is open; the parent's setState alone does not rebuild a route's sheet.
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => ParticipantPickerBottomSheet(
          onAdd: (name, userId) {
            final entry = _PlayerEntry(userId: userId);
            entry.nameController.text = name;
            entry.nameController.addListener(() => setState(() {}));
            setState(() => _players.add(entry));
            setSheetState(() {});
          },
          // Marks players already in the play so they cannot be added twice.
          addedUserIds: _players
              .where((p) => p.userId != null)
              .map((p) => p.userId!)
              .toSet(),
          // Edit carries only gameId/gameName, not the game's min/max, so the
          // game-specific cap still cannot be evaluated here (docs/defects.md
          // D5). The platform ceiling can be, and it is the one the server
          // enforces — without it the picker happily builds a play that
          // updatePlay then rejects.
          atMax: _players.length >= kMaxParticipantsPerPlay,
        ),
      ),
    );
  }

  void _removePlayer(int index) {
    setState(() {
      _players[index].dispose();
      _players.removeAt(index);
    });
  }

  void _save() {
    final participants = _players
        .where((p) => p.nameController.text.trim().isNotEmpty)
        .map(
          (p) => ParticipantInput(
            userId: p.userId,
            name: p.nameController.text.trim(),
            isWinner: p.isWinner,
            score: p.score,
          ),
        )
        .toList();

    if (participants.isEmpty) return;
    if (!participants.any((p) => p.isWinner)) return;

    final location = _locationController.text.trim();
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      UpdatePlayInput(
        playId: widget.detail.playId,
        gameId: _gameId,
        gameName: _gameName,
        playedAt: _playedAt,
        participants: participants,
        location: location.isNotEmpty ? location : null,
        notes: notes.isNotEmpty ? notes : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.editPlayTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(s.addPlaySectionGame),
                  const SizedBox(height: 8),
                  _GamePicker(gameName: _gameName, onTap: _showGamePicker),
                  const SizedBox(height: 24),
                  _SectionLabel(s.addPlaySectionSession),
                  const SizedBox(height: 8),
                  _DateRow(date: _playedAt, onTap: _pickDate),
                  const SizedBox(height: 10),
                  _StyledField(
                    controller: _locationController,
                    hint: s.addPlayLocationHint,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 10),
                  _StyledField(
                    controller: _notesController,
                    hint: s.addPlayNotesHint,
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.addPlayPlayers),
                  const SizedBox(height: 8),
                  ..._players.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlayerRow(
                        entry: e.value,
                        readOnly:
                            e.value.userId != null &&
                            e.value.userId == _currentUserId,
                        canRemove: e.value.userId != _currentUserId,
                        onToggleWinner: () => setState(
                          () => e.value.isWinner = !e.value.isWinner,
                        ),
                        onRemove: () => _removePlayer(e.key),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _AddPlayerButton(onTap: _showParticipantPicker),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _SaveBar(enabled: _canSave, loading: false, onTap: _save),
        ],
      ),
    );
  }
}

// ─── Form sub-widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ).kr,
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: context.colors.amberBorder),
      ],
    );
  }
}

class _GamePicker extends StatelessWidget {
  final String gameName;
  final VoidCallback onTap;

  const _GamePicker({required this.gameName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.casino_outlined,
              color: context.colors.outline,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                gameName,
                style: GoogleFonts.newsreader(
                  color: context.colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ).kr,
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  static String _fmt(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: context.colors.outline,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              _fmt(date),
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.onSurface,
                fontSize: 14,
              ).kr,
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: context.colors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final _PlayerEntry entry;
  final bool readOnly;
  final bool canRemove;
  final VoidCallback onToggleWinner;
  final VoidCallback onRemove;

  const _PlayerRow({
    required this.entry,
    required this.onToggleWinner,
    required this.onRemove,
    this.readOnly = false,
    this.canRemove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(
          color: entry.isWinner
              ? context.colors.primary.withAlpha(120)
              : context.colors.amberBorder,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: entry.nameController,
              readOnly: readOnly,
              enableInteractiveSelection: !readOnly,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.onSurface,
                fontSize: 14,
              ).kr,
              decoration: InputDecoration.collapsed(
                hintText: AppStrings.of(context).addPlayPlayerNameHint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 14,
                ).kr,
              ),
            ),
          ),
          _ScoreField(controller: entry.scoreController),
          GestureDetector(
            onTap: onToggleWinner,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                entry.isWinner
                    ? Icons.emoji_events
                    : Icons.emoji_events_outlined,
                color: entry.isWinner
                    ? context.colors.primary
                    : context.colors.outline,
                size: 20,
              ),
            ),
          ),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                child: Icon(
                  Icons.close,
                  color: context.colors.outline,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 30),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: context.colors.outline, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.onSurface,
                fontSize: 14,
              ).kr,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 14,
                ).kr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final TextEditingController controller;

  const _ScoreField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurface,
          fontSize: 14,
        ).kr,
        decoration: InputDecoration.collapsed(
          hintText: AppStrings.of(context).scoreHint,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 14,
          ).kr,
        ),
      ),
    );
  }
}

class _AddPlayerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlayerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: context.colors.outline, size: 16),
            const SizedBox(width: 6),
            Text(
              AppStrings.of(context).editPlayAddPlayer,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ).kr,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SaveBar({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: enabled
                  ? context.colors.primary
                  : context.colors.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.onPrimary,
                      ),
                    )
                  : Text(
                      AppStrings.of(context).editPlaySaveChanges,
                      style: GoogleFonts.spaceGrotesk(
                        color: enabled
                            ? context.colors.onPrimary
                            : context.colors.outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ).kr,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
