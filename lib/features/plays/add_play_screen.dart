import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/campaign.dart';
import '../../shared/models/catalog_game.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/services/analytics_service.dart';
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
      // Consumer so the sheet re-renders as participants are added while it is
      // open — the "Added" marks and the at-max notice must stay current.
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(addPlayProvider);
          return ParticipantPickerBottomSheet(
            onAdd: _addParticipantFromPicker,
            addedUserIds: state.participants
                .where((p) => p.userId != null)
                .map((p) => p.userId!)
                .toSet(),
            atMax: !state.canAddParticipant,
          );
        },
      ),
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

  // Edits a mission's recorded tries / passed status directly on the selected
  // table, persisting the change and re-pinning the current mission.
  Future<void> _editMission(int stage) async {
    final state = ref.read(addPlayProvider);
    final campaign = state.campaign;
    if (campaign == null) return;
    final axis = stageAxisLabel(
      AppStrings.of(context),
      state.coopSpec?.stageAxis,
    );
    final result = await showDialog<_MissionEdit>(
      context: context,
      builder: (_) => _EditMissionDialog(
        axis: axis,
        stage: stage,
        initialTries: campaign.triesFor(stage),
        initialPassed: campaign.isStageCompleted(stage),
      ),
    );
    if (result == null) return;
    final next = <String, CampaignStage>{...campaign.stages};
    final existing = next['$stage'];
    next['$stage'] = CampaignStage(
      completed: result.passed,
      sessionCount: result.tries,
      lastOutcome: existing?.lastOutcome,
      lastPlayedAt: existing?.lastPlayedAt,
    );
    final updated = campaign.copyWith(stages: next);
    ref.read(addPlayProvider.notifier).setCampaign(updated);
    try {
      await ref.read(campaignRepositoryProvider).saveCampaign(updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).crewSaveFailed)),
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
      final st = ref.read(addPlayProvider);
      ref
          .read(analyticsServiceProvider)
          .logAddPlay(
            gameId: st.selectedGame!.gameId,
            mode: st.isCoop ? 'coop' : 'competitive',
          );
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
        : state.aboveMaxPlayers
        ? s.maxPlayersExceeded(
            state.participants.length - state.maxPlayers!,
            state.maxPlayers!,
          )
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
                      onEditMission: _editMission,
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

/// The co-op session controls. One-shot co-ops (no stage board) record just a
/// team win/loss. Campaign games (The Crew) instead pick a table, surface its
/// per-mission tries record, and log one pass/fail attempt against the current
/// (next-incomplete) mission.
class _CoopControls extends StatelessWidget {
  final AddPlayState state;
  final ValueChanged<String> onOutcome;
  final VoidCallback onPickTable;
  final ValueChanged<int> onEditMission;

  const _CoopControls({
    required this.state,
    required this.onOutcome,
    required this.onPickTable,
    required this.onEditMission,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (!state.hasCampaign) {
      // One-shot cooperative game: team result only.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(s.addPlayResult),
          const SizedBox(height: 8),
          _OutcomeRow(
            wonLabel: s.addPlayWon,
            lostLabel: s.addPlayLost,
            outcome: state.outcome,
            onOutcome: onOutcome,
          ),
        ],
      );
    }

    final spec = state.coopSpec!;
    final axis = stageAxisLabel(s, spec.stageAxis);
    final campaign = state.campaign;
    final current = campaign?.nextIncompleteStage(spec.stageCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(s.addPlayTableCaps),
        const SizedBox(height: 8),
        _TablePickerRow(
          label: campaign == null
              ? s.addPlaySelectTable
              : _rosterSummary(s, campaign),
          selected: campaign != null,
          onTap: onPickTable,
        ),
        if (campaign != null && current != null) ...[
          const SizedBox(height: 20),
          _SectionLabel(s.crewMissionRecordCaps),
          const SizedBox(height: 8),
          _MissionRecordList(
            campaign: campaign,
            axis: axis,
            current: current,
            onEdit: onEditMission,
          ),
          const SizedBox(height: 20),
          _SectionLabel(s.crewCurrentMission),
          const SizedBox(height: 8),
          _CurrentMissionAttempt(
            missionLabel: s.stageLabelNumbered(axis, current),
            passedLabel: s.crewPassed,
            failedLabel: s.crewFailed,
            outcome: state.outcome,
            onOutcome: onOutcome,
          ),
        ],
      ],
    );
  }

  static String _rosterSummary(AppStrings s, Campaign campaign) =>
      campaign.roster.isEmpty
      ? s.campaignUntitledTable
      : campaign.roster.join(', ');
}

/// A pair of win/loss (or pass/fail) buttons wired to [onOutcome].
class _OutcomeRow extends StatelessWidget {
  final String wonLabel;
  final String lostLabel;
  final String? outcome;
  final ValueChanged<String> onOutcome;

  const _OutcomeRow({
    required this.wonLabel,
    required this.lostLabel,
    required this.outcome,
    required this.onOutcome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OutcomeButton(
            label: wonLabel,
            selected: outcome == 'win',
            onTap: () => onOutcome('win'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OutcomeButton(
            label: lostLabel,
            selected: outcome == 'loss',
            onTap: () => onOutcome('loss'),
          ),
        ),
      ],
    );
  }
}

/// The current mission being attempted (pinned, read-only) plus its pass/fail
/// buttons for the single attempt this play logs.
class _CurrentMissionAttempt extends StatelessWidget {
  final String missionLabel;
  final String passedLabel;
  final String failedLabel;
  final String? outcome;
  final ValueChanged<String> onOutcome;

  const _CurrentMissionAttempt({
    required this.missionLabel,
    required this.passedLabel,
    required this.failedLabel,
    required this.outcome,
    required this.onOutcome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.primary.withAlpha(120)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            missionLabel,
            style: GoogleFonts.newsreader(
              color: context.colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _OutcomeRow(
            wonLabel: passedLabel,
            lostLabel: failedLabel,
            outcome: outcome,
            onOutcome: onOutcome,
          ),
        ],
      ),
    );
  }
}

/// The table's per-mission tries record, current mission first then history.
/// Each row is tappable to correct its recorded tries / passed status.
class _MissionRecordList extends StatelessWidget {
  final Campaign campaign;
  final String axis;
  final int current;
  final ValueChanged<int> onEdit;

  const _MissionRecordList({
    required this.campaign,
    required this.axis,
    required this.current,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        for (var n = current; n >= 1; n--)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MissionRecordRow(
              label: s.stageLabelNumbered(axis, n),
              triesLabel: s.crewTriesCount(campaign.triesFor(n)),
              completed: campaign.isStageCompleted(n),
              isCurrent: n == current,
              onTap: () => onEdit(n),
            ),
          ),
      ],
    );
  }
}

class _MissionRecordRow extends StatelessWidget {
  final String label;
  final String triesLabel;
  final bool completed;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MissionRecordRow({
    required this.label,
    required this.triesLabel,
    required this.completed,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(
            color: isCurrent
                ? context.colors.primary.withAlpha(120)
                : context.colors.amberBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed
                  ? context.colors.primary
                  : context.colors.outline,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.newsreader(
                  color: context.colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              triesLabel,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: context.colors.outline, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Result of the edit-mission dialog: the corrected tries count and passed flag.
class _MissionEdit {
  final int tries;
  final bool passed;
  const _MissionEdit(this.tries, this.passed);
}

class _EditMissionDialog extends StatefulWidget {
  final String axis;
  final int stage;
  final int initialTries;
  final bool initialPassed;

  const _EditMissionDialog({
    required this.axis,
    required this.stage,
    required this.initialTries,
    required this.initialPassed,
  });

  @override
  State<_EditMissionDialog> createState() => _EditMissionDialogState();
}

class _EditMissionDialogState extends State<_EditMissionDialog> {
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
    Navigator.of(context).pop(_MissionEdit(n < 0 ? 0 : n, _passed));
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
        ),
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
            ),
            decoration: InputDecoration(
              labelText: s.crewTriesLabel,
              labelStyle: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 13,
              ),
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
                ),
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
            ),
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
            ),
          ),
        ),
      ],
    );
  }
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
