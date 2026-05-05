import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final name = user.displayName ?? '';
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PROFILE',
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(initials: initials),
            const SizedBox(height: 20),
            Text(
              name,
              style: GoogleFonts.newsreader(
                color: kColorOnSurface,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? '',
              style: GoogleFonts.workSans(
                color: kColorOnSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            Container(height: 1, color: kColorOutlineVariant),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kColorPrimary,
                  side: const BorderSide(color: kColorAmberBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GoogleFonts.workSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _signOut(BuildContext context) async {
    Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
  }
}

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kColorPrimary.withValues(alpha: 0.55),
          width: 2,
        ),
        color: kColorSurfaceHigh,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
