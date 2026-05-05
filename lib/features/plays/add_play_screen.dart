import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/catalog_game.dart';
import '../../shared/models/play.dart';
import '../../shared/repositories/game_catalog_repository.dart';
import '../../shared/repositories/play_repository.dart';
import '../../shared/theme/app_theme.dart';

// ─── Player entry (state holder, not a widget) ────────────────────────────────

class _PlayerEntry {
  final TextEditingController nameController = TextEditingController();
  bool isWinner = false;
  String? userId;

  void dispose() => nameController.dispose();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddPlayScreen extends StatefulWidget {
  const AddPlayScreen({super.key});

  @override
  State<AddPlayScreen> createState() => _AddPlayScreenState();
}

class _AddPlayScreenState extends State<AddPlayScreen> {
  String? _gameId;
  String? _gameName;
  DateTime _playedAt = DateTime.now();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_PlayerEntry> _players = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? '';
    if (name.isNotEmpty) {
      final entry = _PlayerEntry();
      entry.nameController.text = name;
      entry.userId = user?.uid;
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
      _gameId != null &&
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
      builder: (_) => _GamePickerSheet(
        onSelect: (id, name) {
          setState(() {
            _gameId = id;
            _gameName = name;
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
    if (picked != null) setState(() => _playedAt = picked);
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

  Future<void> _save() async {
    final participants = _players
        .where((p) => p.nameController.text.trim().isNotEmpty)
        .map(
          (p) => ParticipantInput(
            userId: p.userId,
            name: p.nameController.text.trim(),
            isWinner: p.isWinner,
          ),
        )
        .toList();

    if (_gameId == null || participants.isEmpty) return;

    setState(() => _saving = true);
    try {
      await PlayRepository.instance.createPlay(
        CreatePlayInput(
          gameId: _gameId!,
          gameName: _gameName!,
          playedAt: _playedAt,
          participants: participants,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save. Please try again.',
              style: GoogleFonts.spaceGrotesk(color: kColorOnSurface),
            ),
            backgroundColor: kColorSurfaceHigh,
          ),
        );
        setState(() => _saving = false);
      }
    }
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
          'LOG A PLAY',
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
                  const SizedBox(height: 10),
                  _StyledField(
                    controller: _locationController,
                    hint: 'Location (optional)',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 10),
                  _StyledField(
                    controller: _notesController,
                    hint: 'Notes (optional)',
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
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
          _SaveBar(
            enabled: _canSave && !_saving,
            loading: _saving,
            onTap: _save,
          ),
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
  final String? gameName;
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
                gameName ?? 'Select a game…',
                style: gameName != null
                    ? GoogleFonts.newsreader(
                        color: kColorOnSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      )
                    : GoogleFonts.newsreader(
                        color: kColorOutline,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
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
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: kColorOutline, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
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
                      'SAVE PLAY',
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

// ─── Game picker bottom sheet ─────────────────────────────────────────────────

class _GamePickerSheet extends StatefulWidget {
  final void Function(String gameId, String name) onSelect;

  const _GamePickerSheet({required this.onSelect});

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  final _searchController = TextEditingController();
  List<CatalogGame>? _games;
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetch(null);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchController.text.trim();
      _fetch(q.isEmpty ? null : q);
    });
  }

  Future<void> _fetch(String? search) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final games = await GameCatalogRepository.instance.listBoardGames(
        search: search,
      );
      if (mounted) {
        setState(() {
          _games = games;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Container(
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kColorOutlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'SELECT GAME',
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            Container(height: 1, color: kColorAmberBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
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
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.spaceGrotesk(
                          color: kColorOnSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Search games…',
                          hintStyle: GoogleFonts.spaceGrotesk(
                            color: kColorOutline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: kColorOutline,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: kColorOutline,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                color: kColorOutline,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _fetch(null),
                              child: Text(
                                'RETRY',
                                style: GoogleFonts.spaceGrotesk(
                                  color: kColorPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _games == null
                  ? const Center(
                      child: CircularProgressIndicator(color: kColorPrimary),
                    )
                  : _games!.isEmpty
                  ? Center(
                      child: Text(
                        'No games found',
                        style: GoogleFonts.newsreader(
                          color: kColorOnSurfaceVariant,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _games!.length,
                      itemBuilder: (_, i) {
                        final game = _games![i];
                        return _GameTile(
                          game: game,
                          onTap: () => widget.onSelect(game.gameId, game.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final CatalogGame game;
  final VoidCallback onTap;

  const _GameTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          game.name,
          style: GoogleFonts.newsreader(
            color: kColorOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
