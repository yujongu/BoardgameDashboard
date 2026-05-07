import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/play.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/game_picker_sheet.dart';

// ─── Player entry (local state holder) ───────────────────────────────────────

class _PlayerEntry {
  _PlayerEntry({this.userId, this.score});

  final TextEditingController nameController = TextEditingController();
  bool isWinner = false;
  final String? userId;
  final double? score; // preserved from original, not editable

  void dispose() => nameController.dispose();
}

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
  final List<_PlayerEntry> _players = [];
  @override
  void initState() {
    super.initState();
    _gameId = widget.detail.gameId;
    _gameName = widget.detail.gameName;
    _playedAt = widget.detail.playedAt.toLocal();

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
            primary: kColorPrimary,
            onPrimary: kColorOnPrimary,
            surface: kColorSurface,
            onSurface: kColorOnSurface,
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

  void _addPlayer() {
    final entry = _PlayerEntry();
    entry.nameController.addListener(() => setState(() {}));
    setState(() => _players.add(entry));
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

    Navigator.of(context).pop(
      UpdatePlayInput(
        playId: widget.detail.playId,
        gameId: _gameId,
        gameName: _gameName,
        playedAt: _playedAt,
        participants: participants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'EDIT PLAY',
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kColorAmberBorder),
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
                  _SectionLabel('GAME'),
                  const SizedBox(height: 8),
                  _GamePicker(gameName: _gameName, onTap: _showGamePicker),
                  const SizedBox(height: 24),
                  _SectionLabel('SESSION'),
                  const SizedBox(height: 8),
                  _DateRow(date: _playedAt, onTap: _pickDate),
                  const SizedBox(height: 24),
                  _SectionLabel('PLAYERS'),
                  const SizedBox(height: 8),
                  ..._players.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlayerRow(
                        entry: e.value,
                        onToggleWinner: () => setState(
                          () => e.value.isWinner = !e.value.isWinner,
                        ),
                        onRemove: () => _removePlayer(e.key),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _AddPlayerButton(onTap: _addPlayer),
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
            color: kColorOutline,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: kColorAmberBorder),
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
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.casino_outlined, color: kColorOutline, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                gameName,
                style: GoogleFonts.newsreader(
                  color: kColorOnSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: kColorOutline, size: 20),
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
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: kColorOutline,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              _fmt(date),
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: kColorOutline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final _PlayerEntry entry;
  final VoidCallback onToggleWinner;
  final VoidCallback onRemove;

  const _PlayerRow({
    required this.entry,
    required this.onToggleWinner,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(
          color: entry.isWinner
              ? kColorPrimary.withAlpha(120)
              : kColorAmberBorder,
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
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'Player name',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggleWinner,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                entry.isWinner
                    ? Icons.emoji_events
                    : Icons.emoji_events_outlined,
                color: entry.isWinner ? kColorPrimary : kColorOutline,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
              child: Icon(Icons.close, color: kColorOutline, size: 18),
            ),
          ),
        ],
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
          border: Border.all(color: kColorOutlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: kColorOutline, size: 16),
            const SizedBox(width: 6),
            Text(
              'ADD PLAYER',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
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
              color: enabled ? kColorPrimary : kColorOutlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kColorOnPrimary,
                      ),
                    )
                  : Text(
                      'SAVE CHANGES',
                      style: GoogleFonts.spaceGrotesk(
                        color: enabled ? kColorOnPrimary : kColorOutline,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
