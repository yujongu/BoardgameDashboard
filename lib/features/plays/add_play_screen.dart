import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/catalog_game.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/game_picker_sheet.dart';
import 'add_play_notifier.dart';
import 'participant_picker_sheet.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddPlayScreen extends ConsumerStatefulWidget {
  const AddPlayScreen({super.key});

  @override
  ConsumerState<AddPlayScreen> createState() => _AddPlayScreenState();
}

class _AddPlayScreenState extends ConsumerState<AddPlayScreen> {
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Parallel lists of name/score controllers mirroring state.participants.
  // Invariant: _controllers.length == _scoreControllers.length ==
  // state.participants.length at all times.
  final List<TextEditingController> _controllers = [];
  final List<TextEditingController> _scoreControllers = [];

  @override
  void initState() {
    super.initState();
    final initial = ref.read(addPlayProvider).participants;
    for (final p in initial) {
      _addController(initialText: p.name);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final c in _scoreControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Creates a name + score controller pair whose listeners always resolve
  // their own current index, so removal from the middle of the list doesn't
  // corrupt indices.
  void _addController({String initialText = ''}) {
    final ctrl = TextEditingController(text: initialText);
    ctrl.addListener(() {
      final idx = _controllers.indexOf(ctrl);
      if (idx >= 0) {
        ref
            .read(addPlayProvider.notifier)
            .updateParticipantName(idx, ctrl.text);
      }
    });
    _controllers.add(ctrl);

    final scoreCtrl = TextEditingController();
    scoreCtrl.addListener(() {
      final idx = _scoreControllers.indexOf(scoreCtrl);
      if (idx >= 0) {
        ref
            .read(addPlayProvider.notifier)
            .updateParticipantScore(
              idx,
              double.tryParse(scoreCtrl.text.trim()),
            );
      }
    });
    _scoreControllers.add(scoreCtrl);
  }

  Future<void> _showGamePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GamePickerSheet(
        onSelect: (game) {
          _onGameSelected(game);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onGameSelected(CatalogGame game) {
    ref.read(addPlayProvider.notifier).onGameSelected(game);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(addPlayProvider).playedAt,
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
      ref.read(addPlayProvider.notifier).setPlayedAt(picked);
    }
  }

  void _addParticipantFromPicker(String name, String? userId) {
    _addController(initialText: name);
    ref
        .read(addPlayProvider.notifier)
        .addParticipantWithData(name, userId: userId);
  }

  Future<void> _showParticipantPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ParticipantPickerBottomSheet(onAdd: _addParticipantFromPicker),
    );
  }

  void _removeParticipant(int index) {
    _controllers[index].dispose();
    _controllers.removeAt(index);
    _scoreControllers[index].dispose();
    _scoreControllers.removeAt(index);
    ref.read(addPlayProvider.notifier).removeParticipant(index);
  }

  Future<void> _save() async {
    final notifier = ref.read(addPlayProvider.notifier);
    for (var i = 0; i < _controllers.length; i++) {
      notifier.updateParticipantName(i, _controllers[i].text);
      notifier.updateParticipantScore(
        i,
        double.tryParse(_scoreControllers[i].text.trim()),
      );
    }

    final ok = await notifier.save(
      location: _locationController.text,
      notes: _notesController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).addPlaySaveFailed,
            style: GoogleFonts.spaceGrotesk(color: kColorOnSurface),
          ),
          backgroundColor: kColorSurfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = ref.watch(addPlayProvider);
    final countText = state.maxPlayers != null
        ? s.playersCountMax(state.participants.length, state.maxPlayers!)
        : s.playersCountOnly(state.participants.length);
    final addButtonText = state.canAddParticipant
        ? s.addParticipant
        : s.maxPlayersAdded;
    final saveButtonText = state.belowMinPlayers
        ? s.minPlayersNeeded(state.effectiveMinPlayers)
        : s.savePlay;
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
          s.addPlayTitle,
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
                  _SectionLabel(s.addPlaySectionGame),
                  const SizedBox(height: 8),
                  _GamePicker(
                    gameName: state.selectedGame?.name,
                    onTap: _showGamePicker,
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.addPlaySectionSession),
                  const SizedBox(height: 8),
                  _DateRow(date: state.playedAt, onTap: _pickDate),
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
                  _PlayersSectionHeader(countText: countText),
                  const SizedBox(height: 8),
                  ...state.participants.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlayerRow(
                        controller: _controllers[e.key],
                        scoreController: _scoreControllers[e.key],
                        isWinner: e.value.isWinner,
                        canRemove: e.key != 0,
                        readOnly: e.value.userId == state.currentUserId,
                        onToggleWinner: () => ref
                            .read(addPlayProvider.notifier)
                            .toggleWinner(e.key),
                        onRemove: () => _removeParticipant(e.key),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _AddParticipantButton(
                    label: addButtonText,
                    enabled: state.canAddParticipant,
                    onTap: state.canAddParticipant
                        ? _showParticipantPicker
                        : null,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _SaveBar(
            enabled: state.canSave && !state.saving,
            loading: state.saving,
            buttonText: saveButtonText,
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

class _PlayersSectionHeader extends StatelessWidget {
  final String countText;

  const _PlayersSectionHeader({required this.countText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.of(context).addPlayPlayers,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            Text(
              countText,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                gameName ?? AppStrings.of(context).addPlaySelectGame,
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
  final TextEditingController controller;
  final TextEditingController scoreController;
  final bool isWinner;
  final bool canRemove;
  final bool readOnly;
  final VoidCallback onToggleWinner;
  final VoidCallback onRemove;

  const _PlayerRow({
    required this.controller,
    required this.scoreController,
    required this.isWinner,
    required this.onToggleWinner,
    required this.onRemove,
    this.canRemove = true,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(
          color: isWinner ? kColorPrimary.withAlpha(120) : kColorAmberBorder,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              enableInteractiveSelection: !readOnly,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration.collapsed(
                hintText: AppStrings.of(context).addPlayPlayerNameHint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          _ScoreField(controller: scoreController),
          GestureDetector(
            onTap: onToggleWinner,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                isWinner ? Icons.emoji_events : Icons.emoji_events_outlined,
                color: isWinner ? kColorPrimary : kColorOutline,
                size: 20,
              ),
            ),
          ),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                child: Icon(Icons.close, color: kColorOutline, size: 18),
              ),
            )
          else
            const SizedBox(width: 30),
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
        style: GoogleFonts.spaceGrotesk(color: kColorOnSurface, fontSize: 14),
        decoration: InputDecoration.collapsed(
          hintText: AppStrings.of(context).scoreHint,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: kColorOutline,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AddParticipantButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _AddParticipantButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? kColorOutlineVariant
                : kColorOutlineVariant.withAlpha(80),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: enabled ? kColorOutline : kColorOutlineVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final String buttonText;
  final VoidCallback onTap;

  const _SaveBar({
    required this.enabled,
    required this.loading,
    required this.buttonText,
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
                      buttonText,
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
