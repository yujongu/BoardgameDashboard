import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/providers/theme_mode_provider.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

/// App version shown in the About section. Kept in sync with `pubspec.yaml`.
const String kAppVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.settingsTitle,
          style: GoogleFonts.newsreader(
            color: c.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.amberBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          _SectionHeader(label: s.settingsAppearance),
          _ThemeOption(
            label: s.settingsThemeSystem,
            icon: Icons.brightness_auto_outlined,
            selected: mode == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.system),
          ),
          _ThemeOption(
            label: s.settingsThemeLight,
            icon: Icons.light_mode_outlined,
            selected: mode == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.light),
          ),
          _ThemeOption(
            label: s.settingsThemeDark,
            icon: Icons.dark_mode_outlined,
            selected: mode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
          ),
          const SizedBox(height: 32),
          _SectionHeader(label: s.settingsAbout),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.settingsVersion,
                    style: GoogleFonts.workSans(
                      color: c.onSurface,
                      fontSize: 16,
                    ).kr,
                  ),
                ),
                Text(
                  kAppVersion,
                  style: GoogleFonts.workSans(
                    color: c.onSurfaceVariant,
                    fontSize: 15,
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

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ).kr,
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.surfaceHigh : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.primary : c.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? c.primary : c.outline, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.workSans(
                  color: c.onSurface,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ).kr,
              ),
            ),
            if (selected) Icon(Icons.check, color: c.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
