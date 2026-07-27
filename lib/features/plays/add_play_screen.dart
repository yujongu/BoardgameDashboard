import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/campaign.dart';
import '../../shared/models/catalog_game.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/game_picker_sheet.dart';
import '../library/campaign_record_section.dart';
import '../library/campaign_registry.dart';
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

  Future<void> _pickTable() async {
    final state = ref.read(addPlayProvider);
    final game = state.selectedGame;
    if (game == null) return;
    final repo = ref.read(campaignRepositoryProvider);
    final campaigns = await repo.fetchCampaignsForGame(game.gameId);
    if (!mounted) return;
    final pick = await showModalBottomSheet<_TablePick>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TablePickerSheet(campaigns: campaigns, spec: state.coopSpec!),
    );
    if (pick == null) return;
    if (pick is _PickExisting) {
      ref.read(addPlayProvider.notifier).setCampaign(pick.campaign);
    } else {
      await _createTable();
    }
  }

  Future<void> _createTable() async {
    final state = ref.read(addPlayProvider);
    final game = state.selectedGame;
    if (game == null) return;
    final names = state.participants
        .map((p) => p.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final memberIds = state.participants
        .map((p) => p.userId)
        .whereType<String>()
        .toList();
    try {
      final campaign = await ref
          .read(campaignRepositoryProvider)
          .createCampaign(
            gameId: game.gameId,
            gameName: game.name,
            roster: names,
            memberIds: memberIds,
          );
      if (!mounted) return;
      ref.read(addPlayProvider.notifier).setCampaign(campaign);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).campaignCreateFailed)),
      );
    }
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
            style: GoogleFonts.spaceGrotesk(color: context.colors.onSurface),
          ),
          backgroundColor: context.colors.surfaceHigh,
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
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.addPlayTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
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
                  if (state.isCoop) ...[
                    const SizedBox(height: 24),
                    _CoopControls(
                      state: state,
                      onOutcome: (o) =>
                          ref.read(addPlayProvider.notifier).setOutcome(o),
                      onPickTable: _pickTable,
                      onStage: (v) =>
                          ref.read(addPlayProvider.notifier).setStage(v),
                    ),
                  ],
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
                        showWinner: !state.isCoop,
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
            color: context.colors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: context.colors.amberBorder),
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
                color: context.colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            Text(
              countText,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: context.colors.amberBorder),
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
                gameName ?? AppStrings.of(context).addPlaySelectGame,
                style: gameName != null
                    ? GoogleFonts.newsreader(
                        color: context.colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      )
                    : GoogleFonts.newsreader(
                        color: context.colors.outline,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
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
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: context.colors.outline, size: 20),
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
              ),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
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
  final bool showWinner;
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
    this.showWinner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(
          color: isWinner
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
              controller: controller,
              readOnly: readOnly,
              enableInteractiveSelection: !readOnly,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration.collapsed(
                hintText: AppStrings.of(context).addPlayPlayerNameHint,
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (showWinner) ...[
            _ScoreField(controller: scoreController),
            GestureDetector(
              onTap: onToggleWinner,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  isWinner ? Icons.emoji_events : Icons.emoji_events_outlined,
                  color: isWinner
                      ? context.colors.primary
                      : context.colors.outline,
                  size: 20,
                ),
              ),
            ),
          ],
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
        ),
        decoration: InputDecoration.collapsed(
          hintText: AppStrings.of(context).scoreHint,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
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
                ? context.colors.outlineVariant
                : context.colors.outlineVariant.withAlpha(80),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: enabled
                  ? context.colors.outline
                  : context.colors.outlineVariant,
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
                      buttonText,
                      style: GoogleFonts.spaceGrotesk(
                        color: enabled
                            ? context.colors.onPrimary
                            : context.colors.outline,
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

// ─── Cooperative controls ─────────────────────────────────────────────────────

/// Result of the table picker sheet: an existing table or a request to create one.
sealed class _TablePick {
  const _TablePick();
}

class _PickExisting extends _TablePick {
  final Campaign campaign;
  const _PickExisting(this.campaign);
}

class _PickNew extends _TablePick {
  const _PickNew();
}

/// The co-op session controls: team result plus (for campaign games) the table
/// and stage the session advances.
class _CoopControls extends StatelessWidget {
  final AddPlayState state;
  final ValueChanged<String> onOutcome;
  final VoidCallback onPickTable;
  final ValueChanged<int> onStage;

  const _CoopControls({
    required this.state,
    required this.onOutcome,
    required this.onPickTable,
    required this.onStage,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final spec = state.coopSpec!;
    final campaign = state.campaign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(s.addPlayResult),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _OutcomeButton(
                label: s.addPlayWon,
                selected: state.outcome == 'win',
                onTap: () => onOutcome('win'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OutcomeButton(
                label: s.addPlayLost,
                selected: state.outcome == 'loss',
                onTap: () => onOutcome('loss'),
              ),
            ),
          ],
        ),
        if (state.hasCampaign) ...[
          const SizedBox(height: 20),
          _SectionLabel(s.addPlayTableCaps),
          const SizedBox(height: 8),
          _TablePickerRow(
            label: campaign == null
                ? s.addPlaySelectTable
                : _rosterSummary(s, campaign),
            selected: campaign != null,
            onTap: onPickTable,
          ),
          if (campaign != null && state.stage != null) ...[
            const SizedBox(height: 20),
            _SectionLabel(s.addPlayStageCaps),
            const SizedBox(height: 8),
            _StageStepper(
              axis: stageAxisLabel(s, spec.stageAxis),
              stage: state.stage!,
              total: spec.stageCount,
              onChanged: onStage,
            ),
          ],
        ],
      ],
    );
  }

  static String _rosterSummary(AppStrings s, Campaign campaign) =>
      campaign.roster.isEmpty
      ? s.campaignUntitledTable
      : campaign.roster.join(', ');
}

class _OutcomeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withAlpha(30)
              : context.colors.surfaceHigh,
          border: Border.all(
            color: selected
                ? context.colors.primary
                : context.colors.amberBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: selected ? context.colors.primary : context.colors.outline,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TablePickerRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TablePickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
              Icons.groups_outlined,
              color: context.colors.outline,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? GoogleFonts.newsreader(
                        color: context.colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      )
                    : GoogleFonts.newsreader(
                        color: context.colors.outline,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StageStepper extends StatelessWidget {
  final String axis;
  final int stage;
  final int total;
  final ValueChanged<int> onChanged;

  const _StageStepper({
    required this.axis,
    required this.stage,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: context.colors.primary,
            disabledColor: context.colors.outlineVariant,
            onPressed: stage > 1 ? () => onChanged(stage - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$axis $stage / $total',
              style: GoogleFonts.newsreader(
                color: context.colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: context.colors.primary,
            disabledColor: context.colors.outlineVariant,
            onPressed: stage < total ? () => onChanged(stage + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the caller's tables for a game plus a "new table" row.
class _TablePickerSheet extends StatelessWidget {
  final List<Campaign> campaigns;
  final CoopSpec spec;

  const _TablePickerSheet({required this.campaigns, required this.spec});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in campaigns)
              ListTile(
                leading: Icon(
                  Icons.groups_outlined,
                  color: context.colors.outline,
                ),
                title: Text(
                  c.roster.isEmpty
                      ? s.campaignUntitledTable
                      : c.roster.join(', '),
                  style: GoogleFonts.newsreader(
                    color: context.colors.onSurface,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  s.campaignStageProgress(c.completedCount, spec.stageCount),
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(_PickExisting(c)),
              ),
            ListTile(
              leading: Icon(Icons.add, color: context.colors.primary),
              title: Text(
                s.campaignNewTable,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              onTap: () => Navigator.of(context).pop(const _PickNew()),
            ),
          ],
        ),
      ),
    );
  }
}
