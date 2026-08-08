import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_fonts.dart';

/// Final score for one player: Terraform Rating + 5 VP per claimed milestone +
/// award VP + greenery tiles (1 VP each) + city-adjacency VP + card VP.
int terraformingMarsTotal({
  required int terraformRating,
  required int milestones,
  required int awardVp,
  required int greeneries,
  required int cityPoints,
  required int cardVp,
}) =>
    terraformRating +
    milestones * 5 +
    awardVp +
    greeneries +
    cityPoints +
    cardVp;

class TerraformingMarsCalculatorScreen extends StatefulWidget {
  const TerraformingMarsCalculatorScreen({super.key});

  @override
  State<TerraformingMarsCalculatorScreen> createState() =>
      _TerraformingMarsCalculatorScreenState();
}

class _TerraformingMarsCalculatorScreenState
    extends State<TerraformingMarsCalculatorScreen> {
  static const _marsRed = Color(0xFFD95B2B);
  // Deepened for the light theme — the bright original drops to ~3.5:1 against
  // the paper background, marginal for the small +VP labels.
  static const _marsRedLight = Color(0xFFB2401A);

  int _tr = 20;
  int _milestones = 0;
  int _awardVp = 0;
  int _greeneries = 0;
  int _cityPoints = 0;
  int _cardVp = 0;

  int get _total => terraformingMarsTotal(
    terraformRating: _tr,
    milestones: _milestones,
    awardVp: _awardVp,
    greeneries: _greeneries,
    cityPoints: _cityPoints,
    cardVp: _cardVp,
  );

  void _reset() {
    setState(() {
      _tr = 20;
      _milestones = 0;
      _awardVp = 0;
      _greeneries = 0;
      _cityPoints = 0;
      _cardVp = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final marsRed = Theme.of(context).brightness == Brightness.dark
        ? _marsRed
        : _marsRedLight;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          s.terraformingMarsTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
          ).kr,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _reset,
              child: Text(
                s.calcReset,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ).kr,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _ScoreRow(
                  label: s.tmTerraformRating,
                  hint: s.tmVpEach,
                  value: _tr,
                  vp: _tr,
                  min: 0,
                  max: 63,
                  color: marsRed,
                  onChanged: (v) => setState(() => _tr = v),
                ),
                _ScoreRow(
                  label: s.tmMilestones,
                  hint: s.tmMilestonesHint,
                  value: _milestones,
                  vp: _milestones * 5,
                  min: 0,
                  max: 3,
                  color: marsRed,
                  onChanged: (v) => setState(() => _milestones = v),
                ),
                _ScoreRow(
                  label: s.tmAward,
                  hint: s.tmAwardHint,
                  value: _awardVp,
                  vp: _awardVp,
                  min: 0,
                  max: 15,
                  color: marsRed,
                  onChanged: (v) => setState(() => _awardVp = v),
                ),
                _ScoreRow(
                  label: s.tmGreenery,
                  hint: s.tmVpEach,
                  value: _greeneries,
                  vp: _greeneries,
                  min: 0,
                  max: 50,
                  color: marsRed,
                  onChanged: (v) => setState(() => _greeneries = v),
                ),
                _ScoreRow(
                  label: s.tmCity,
                  hint: s.tmCityHint,
                  value: _cityPoints,
                  vp: _cityPoints,
                  min: 0,
                  max: 50,
                  color: marsRed,
                  onChanged: (v) => setState(() => _cityPoints = v),
                ),
                _ScoreRow(
                  label: s.tmCardVp,
                  hint: s.tmCardVpHint,
                  value: _cardVp,
                  vp: _cardVp,
                  min: 0,
                  max: 100,
                  color: marsRed,
                  onChanged: (v) => setState(() => _cardVp = v),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.appBarBackground,
              border: Border(
                top: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.calcTotal,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ).kr,
                ),
                Text(
                  '$_total',
                  style: GoogleFonts.newsreader(
                    color: context.colors.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w600,
                  ).kr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final int vp;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ScoreRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.vp,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.newsreader(
                    color: context.colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ).kr,
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ).kr,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '+$vp',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: vp > 0 ? color : context.colors.outline,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ).kr,
            ),
          ),
          const SizedBox(width: 8),
          _StepperControl(
            value: value,
            min: min,
            max: max,
            color: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StepperControl extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _StepperControl({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  State<_StepperControl> createState() => _StepperControlState();
}

class _StepperControlState extends State<_StepperControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_StepperControl old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.text = '${widget.value}';
      if (_focusNode.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _commit();
    }
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      widget.onChanged(clamped);
    } else {
      _controller.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          color: widget.color,
          enabled: widget.value > widget.min,
          onTap: () => widget.onChanged(widget.value - 1),
        ),
        SizedBox(
          width: 44,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: context.colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ).kr,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            // iOS does not unfocus a field when you tap outside it, and the
            // number pad has no Return key to fire onSubmitted — without this
            // the typed value stays visible but uncommitted and the total is
            // silently stale. Unfocusing routes through _onFocusChange.
            onTapOutside: (_) => _focusNode.unfocus(),
            onSubmitted: (_) {
              _commit();
              _focusNode.unfocus();
            },
          ),
        ),
        _StepButton(
          icon: Icons.add,
          color: widget.color,
          enabled: widget.value < widget.max,
          onTap: () => widget.onChanged(widget.value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? widget.color : context.colors.outlineVariant;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _pressed && widget.enabled
              ? widget.color.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Icon(widget.icon, color: color, size: 16),
      ),
    );
  }
}
