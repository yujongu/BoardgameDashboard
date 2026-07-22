import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/crew_campaign.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_theme.dart';

const kTheCrewPlanetNineGameId = 'the-crew-the-quest-for-planet-nine-2019';
const kTheCrewMissionCount = 50;

/// Campaign record sheet for The Crew: crew roster plus the mission the whole
/// crew has reached. Loads and saves the signed-in user's campaign doc.
class CrewRecordSection extends ConsumerStatefulWidget {
  final String gameId;

  const CrewRecordSection({super.key, required this.gameId});

  @override
  ConsumerState<CrewRecordSection> createState() => _CrewRecordSectionState();
}

class _CrewRecordSectionState extends ConsumerState<CrewRecordSection> {
  CrewCampaign? _campaign;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final campaign = await ref
          .read(campaignRepositoryProvider)
          .fetchCampaign(widget.gameId);
      if (!mounted) return;
      setState(() {
        _campaign =
            campaign ?? const CrewCampaign(crewMembers: [], currentMission: 1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _update(CrewCampaign next) async {
    setState(() => _campaign = next);
    try {
      await ref
          .read(campaignRepositoryProvider)
          .saveCampaign(widget.gameId, next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).crewSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.of(context).crewCampaignRecord,
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: kColorAmberBorder),
        const SizedBox(height: 12),
        if (_error != null)
          _LoadErrorRow(onRetry: _load)
        else if (_campaign == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: kColorPrimary,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else
          CrewRecordCard(campaign: _campaign!, onChanged: _update),
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
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            s.commonRetry,
            style: GoogleFonts.spaceGrotesk(
              color: kColorPrimary,
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

/// Pure record-sheet card: renders the campaign and reports edits upward.
class CrewRecordCard extends StatelessWidget {
  final CrewCampaign campaign;
  final ValueChanged<CrewCampaign> onChanged;

  const CrewRecordCard({
    super.key,
    required this.campaign,
    required this.onChanged,
  });

  void _setMission(int mission) {
    onChanged(
      CrewCampaign(
        crewMembers: campaign.crewMembers,
        currentMission: mission.clamp(1, kTheCrewMissionCount),
      ),
    );
  }

  Future<void> _addMember(BuildContext context) async {
    final s = AppStrings.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: s.crewAddMemberTitle,
        hintText: s.crewNameHint,
      ),
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || campaign.crewMembers.contains(trimmed)) return;
    onChanged(
      CrewCampaign(
        crewMembers: [...campaign.crewMembers, trimmed],
        currentMission: campaign.currentMission,
      ),
    );
  }

  void _removeMember(String name) {
    onChanged(
      CrewCampaign(
        crewMembers: campaign.crewMembers.where((m) => m != name).toList(),
        currentMission: campaign.currentMission,
      ),
    );
  }

  Future<void> _editMission(BuildContext context) async {
    final s = AppStrings.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: s.crewSetMissionTitle,
        hintText: s.crewMissionRangeHint(kTheCrewMissionCount),
        numeric: true,
      ),
    );
    final mission = int.tryParse(entered ?? '');
    if (mission == null) return;
    _setMission(mission);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CaptionLabel(s.crewSectionCrew),
              GestureDetector(
                onTap: () => _addMember(context),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: kColorPrimary, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      s.crewAdd,
                      style: GoogleFonts.spaceGrotesk(
                        color: kColorPrimary,
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
          if (campaign.crewMembers.isEmpty)
            Text(
              s.crewNoMembers,
              style: GoogleFonts.newsreader(
                color: kColorOutline,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in campaign.crewMembers)
                  _MemberChip(
                    name: member,
                    onRemove: () => _removeMember(member),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Container(height: 1, color: kColorOutlineVariant),
          const SizedBox(height: 14),
          Center(child: _CaptionLabel(s.crewCurrentMission)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: kColorPrimary,
                disabledColor: kColorOutlineVariant,
                onPressed: campaign.currentMission > 1
                    ? () => _setMission(campaign.currentMission - 1)
                    : null,
              ),
              GestureDetector(
                onTap: () => _editMission(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${campaign.currentMission}',
                        style: GoogleFonts.newsreader(
                          color: kColorPrimary,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        s.crewMissionDenominator(kTheCrewMissionCount),
                        style: GoogleFonts.newsreader(
                          color: kColorOutline,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: kColorPrimary,
                disabledColor: kColorOutlineVariant,
                onPressed: campaign.currentMission < kTheCrewMissionCount
                    ? () => _setMission(campaign.currentMission + 1)
                    : null,
              ),
            ],
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
        color: kColorOnSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _MemberChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kColorOutlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: kColorOutline, size: 14),
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
      backgroundColor: kColorSurfaceHigh,
      title: Text(
        widget.title,
        style: GoogleFonts.newsreader(color: kColorOnSurface, fontSize: 20),
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
        style: GoogleFonts.spaceGrotesk(color: kColorOnSurface, fontSize: 15),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.spaceGrotesk(
            color: kColorOutline,
            fontSize: 15,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: kColorOutlineVariant),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: kColorPrimary),
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
              color: kColorOutline,
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
              color: kColorPrimary,
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
