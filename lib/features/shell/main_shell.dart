import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/providers/providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../auth/profile_screen.dart';
import '../friends/friends_screen.dart';
import '../home/home_tab.dart';
import '../library/library_tab.dart';
import '../plays/add_play_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  Future<void> _openAddPlay() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddPlayScreen()));
    // Bust caches so the home tab and library reflect the new play immediately.
    ref.invalidate(recentPlaysProvider);
    ref.invalidate(libraryProvider);
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        ref.watch(currentUserProvider).valueOrNull?.displayName ?? '';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeTab(displayName: displayName, onProfileTap: _openProfile),
          LibraryTab(displayName: displayName, onProfileTap: _openProfile),
          const FriendsScreen(embedded: true),
        ],
      ),
      // Logging a play only makes sense on Home/Library, not the Friends tab.
      floatingActionButton: _selectedIndex < 2
          ? _AddFab(onTap: _openAddPlay)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: context.colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: context.colors.primary.withAlpha(26),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(Icons.add, color: context.colors.onPrimary, size: 28),
      ),
    );
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.appBarBackground,
        border: Border(top: BorderSide(color: context.colors.amberBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: AppStrings.of(context).navHome,
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: AppStrings.of(context).navLibrary,
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.group_outlined,
                activeIcon: Icons.group,
                label: AppStrings.of(context).navFriends,
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.primary : context.colors.outline;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ).kr,
            ),
          ],
        ),
      ),
    );
  }
}
