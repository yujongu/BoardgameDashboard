import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class ProfileAppBar extends StatelessWidget {
  final String displayName;
  final VoidCallback onProfileTap;

  const ProfileAppBar({
    super.key,
    required this.displayName,
    required this.onProfileTap,
  });

  String get _initials {
    final parts = displayName
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0A0905),
      expandedHeight: kToolbarHeight,
      collapsedHeight: kToolbarHeight,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kColorAmberBorder),
      ),
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Row(
              children: [
                GestureDetector(
                  key: const Key('profileAvatarBtn'),
                  onTap: onProfileTap,
                  child: _ProfileAvatar(initials: _initials),
                ),
                const SizedBox(width: 14),
                Text(
                  displayName.toUpperCase(),
                  style: GoogleFonts.newsreader(
                    color: kColorPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String initials;

  const _ProfileAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kColorPrimary.withAlpha(140), width: 1.5),
        color: kColorSurfaceHigh,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.newsreader(
            color: kColorPrimary.withAlpha(180),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
