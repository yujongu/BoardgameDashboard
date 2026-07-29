import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/campaign.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_colors.dart';
import 'campaign_registry.dart';
import 'edit_mission_dialog.dart';
import 'new_table_sheet.dart';

/// Localized singular label for a campaign's stage axis (Mission/Scenario/Month).
String stageAxisLabel(AppStrings s, StageAxis? axis) {
  switch (axis) {
    case StageAxis.scenario:
      return s.stageAxisScenario;
    case StageAxis.month:
      return s.stageAxisMonth;
    case StageAxis.mission:
    case null:
      return s.stageAxisMission;
  }
}

/// Game-detail section listing the signed-in user's campaigns (tables) for a
/// game with a stage board, plus a "new table" action. Each table is shared
/// with everyone who plays at it; co-op play logging advances the board.
class CampaignSection extends ConsumerStatefulWidget {
  final String gameId;
  final String gameName;
  final CoopSpec spec;

  const CampaignSection({
    super.key,
    required this.gameId,
    required this.gameName,
    required this.spec,
  });

  @override
  ConsumerState<CampaignSection> createState() => _CampaignSectionState();
}

class _CampaignSectionState extends ConsumerState<CampaignSection> {
  List<Campaign>? _campaigns;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final campaigns = await ref
          .read(campaignRepositoryProvider)
          .fetchCampaignsForGame(widget.gameId);
      if (!mounted) return;
      setState(() => _campaigns = campaigns);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _newTable() async {
    final seats = await showNewTableSheet(context);
    if (seats == null || !mounted) return;
    try {
      await ref
          .read(campaignRepositoryProvider)
          .createCampaign(
            gameId: widget.gameId,
            gameName: widget.gameName,
            participants: seats,
            creatorName: seats.first.name,
          );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).campaignCreateFailed)),
      );
    }
  }

  Future<void> _save(Campaign next) async {
    // Optimistic: reflect the edit locally, then persist.
    setState(() {
      final list = [...?_campaigns];
      final i = list.indexWhere((c) => c.id == next.id);
      if (i >= 0) list[i] = next;
      _campaigns = list;
    });
    try {
      await ref.read(campaignRepositoryProvider).saveCampaign(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).crewSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              s.campaignsTitle,
              style: GoogleFonts.newsreader(
                color: context.colors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            GestureDetector(
              onTap: _newTable,
              child: Row(
                children: [
                  Icon(Icons.add, color: context.colors.primary, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    s.campaignNewTable,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: context.colors.amberBorder),
        const SizedBox(height: 12),
        if (_error != null)
          _LoadErrorRow(onRetry: _load)
        else if (_campaigns == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_campaigns!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.campaignNoTables,
              style: GoogleFonts.newsreader(
                color: context.colors.outline,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final campaign in _campaigns!) ...[
            CampaignCard(
              campaign: campaign,
              spec: widget.spec,
              onChanged: _save,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LoadErrorRow extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadErrorRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            s.crewLoadFailed,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 13,
            ),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            s.commonRetry,
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

/// One table: roster chips (manual edits) + a linear progress stepper over the
/// game's stages. The stepper reflects the furthest incomplete stage; setting
/// it marks earlier stages complete. Play logging advances individual stages.
class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final CoopSpec spec;
  final ValueChanged<Campaign> onChanged;

  const CampaignCard({
    super.key,
    required this.campaign,
    required this.spec,
    required this.onChanged,
  });

  int get _current => campaign.nextIncompleteStage(spec.stageCount);

  void _setCurrent(int stage) {
    final target = stage.clamp(1, spec.stageCount);
    // Mark stages before [target] complete, [target] onward incomplete,
    // preserving any recorded session data on each stage.
    final next = <String, CampaignStage>{...campaign.stages};
    for (var i = 1; i <= spec.stageCount; i++) {
      final key = '$i';
      final existing = next[key];
      next[key] = CampaignStage(
        completed: i < target,
        sessionCount: existing?.sessionCount ?? 0,
        lastOutcome: existing?.lastOutcome,
        lastPlayedAt: existing?.lastPlayedAt,
      );
    }
    onChanged(campaign.copyWith(stages: next));
  }

  Future<void> _editStage(BuildContext context) async {
    final s = AppStrings.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: stageAxisLabel(s, spec.stageAxis),
        hintText: s.crewMissionRangeHint(spec.stageCount),
        numeric: true,
      ),
    );
    final stage = int.tryParse(entered ?? '');
    if (stage == null) return;
    _setCurrent(stage);
  }

  /// Corrects the tries and passed status of the last completed stage.
  ///
  /// Campaign progress latches: logging a win marks a stage complete, and
  /// deleting that play does not rewind the board — a mission the team really
  /// beat should stay beaten even if the play record is tidied up. That leaves
  /// no way to take back a stage marked complete by mistake, which is what this
  /// provides. The ± stepper can already un-complete a run of stages, but it
  /// preserves each stage's recorded tries; only this can correct those.
  Future<void> _correctPreviousStage(BuildContext context) async {
    final target = _current - 1;
    if (target < 1) return;
    final result = await showDialog<MissionEdit>(
      context: context,
      builder: (_) => EditMissionDialog(
        axis: stageAxisLabel(AppStrings.of(context), spec.stageAxis),
        stage: target,
        initialTries: campaign.triesFor(target),
        initialPassed: campaign.isStageCompleted(target),
      ),
    );
    if (result == null) return;
    final next = <String, CampaignStage>{...campaign.stages};
    final existing = next['$target'];
    next['$target'] = CampaignStage(
      completed: result.passed,
      sessionCount: result.tries,
      lastOutcome: existing?.lastOutcome,
      lastPlayedAt: existing?.lastPlayedAt,
    );
    onChanged(campaign.copyWith(stages: next));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The seats are fixed when the table is created, so this is a plain
          // read-only list — no add affordance, no remove on the chips.
          _CaptionLabel(s.crewSectionCrew),
          const SizedBox(height: 10),
          if (campaign.participants.isEmpty)
            Text(
              s.crewNoMembers,
              style: GoogleFonts.newsreader(
                color: context.colors.outline,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in campaign.participants)
                  _MemberChip(name: member.name),
              ],
            ),
          const SizedBox(height: 16),
          Container(height: 1, color: context.colors.outlineVariant),
          const SizedBox(height: 14),
          Center(
            child: _CaptionLabel(
              stageAxisLabel(s, spec.stageAxis).toUpperCase(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: context.colors.primary,
                disabledColor: context.colors.outlineVariant,
                onPressed: _current > 1
                    ? () => _setCurrent(_current - 1)
                    : null,
              ),
              GestureDetector(
                onTap: () => _editStage(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_current',
                        style: GoogleFonts.newsreader(
                          color: context.colors.primary,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        s.crewMissionDenominator(spec.stageCount),
                        style: GoogleFonts.newsreader(
                          color: context.colors.outline,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: context.colors.primary,
                disabledColor: context.colors.outlineVariant,
                onPressed: _current < spec.stageCount
                    ? () => _setCurrent(_current + 1)
                    : null,
              ),
            ],
          ),
          // Undo path for the latch: nothing else on this card can take back a
          // stage marked complete, or correct the tries a deleted play left
          // behind. Hidden at stage 1, where nothing is completed yet.
          if (_current > 1)
            TextButton(
              onPressed: () => _correctPreviousStage(context),
              child: Text(
                s.campaignCorrectStage(
                  s.stageLabelNumbered(
                    stageAxisLabel(s, spec.stageAxis),
                    _current - 1,
                  ),
                ),
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptionLabel extends StatelessWidget {
  final String text;

  const _CaptionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        color: context.colors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name;

  const _MemberChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final bool numeric;

  const _TextInputDialog({
    required this.title,
    required this.hintText,
    this.numeric = false,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      backgroundColor: context.colors.surfaceHigh,
      title: Text(
        widget.title,
        style: GoogleFonts.newsreader(
          color: context.colors.onSurface,
          fontSize: 20,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.numeric
            ? TextInputType.number
            : TextInputType.text,
        inputFormatters: widget.numeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurface,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 15,
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
