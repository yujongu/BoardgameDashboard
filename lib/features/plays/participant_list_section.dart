import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/friend.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'add_play_notifier.dart';
import 'participant_picker_controller.dart';

class ParticipantListSection extends ConsumerWidget {
  final void Function(String name, String? userId) onAdd;

  const ParticipantListSection({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final pickerState = ref.watch(participantPickerProvider);
    final addPlayState = ref.watch(addPlayProvider);
    final friendsAsync = ref.watch(friendListProvider);

    final selectedIds = addPlayState.participants
        .where((p) => p.userId != null)
        .map((p) => p.userId!)
        .toSet();
    final atMax = !addPlayState.canAddParticipant;

    // skipLoadingOnRefresh is true by default — when retry() uses
    // copyWithPrevious, previous data stays visible instead of flashing a
    // full-screen spinner.
    return friendsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: kColorPrimary)),
      error: (err, stack) {
        dev.log(
          'friendListProvider error',
          name: 'ParticipantListSection',
          error: err,
          stackTrace: stack,
        );
        return _FriendsErrorPanel(
          onRetry: () => ref.invalidate(friendListProvider),
        );
      },
      data: (friends) => _buildList(
        s: s,
        pickerState: pickerState,
        friends: friends,
        selectedIds: selectedIds,
        atMax: atMax,
      ),
    );
  }

  Widget _buildList({
    required AppStrings s,
    required PickerSearchState pickerState,
    required List<FriendSummary> friends,
    required Set<String> selectedIds,
    required bool atMax,
  }) {
    final query = pickerState.query.trim();
    final friendIds = friends.map((f) => f.userId).toSet();

    final filteredFriends = query.isEmpty
        ? friends
        : friends
              .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
              .toList();

    // Only non-friend, non-selected Firestore results; non-empty only on query.
    final userResults = query.isEmpty
        ? <UserSearchResult>[]
        : pickerState.searchResults
              .where((r) => !friendIds.contains(r.userId))
              .where((r) => !selectedIds.contains(r.userId))
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (filteredFriends.isNotEmpty) ...[
          _SectionHeader(s.friendsTitle),
          ...filteredFriends.map((f) {
            final isSelected = selectedIds.contains(f.userId);
            return FriendListItem(
              name: f.name,
              photoUrl: f.photoUrl,
              isSelected: isSelected,
              disabled: atMax && !isSelected,
              onTap: isSelected || atMax ? null : () => onAdd(f.name, f.userId),
            );
          }),
        ] else if (query.isEmpty && friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              s.participantNoFriends,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                color: kColorOutline,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        if (query.isNotEmpty) ...[
          if (pickerState.loadingSearch)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: kColorOutline,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            )
          else if (userResults.isNotEmpty) ...[
            _SectionHeader(s.participantSectionUsers),
            ...userResults.map(
              (u) => UserListItem(
                name: u.name,
                photoUrl: u.photoUrl,
                disabled: atMax,
                onTap: atMax ? null : () => onAdd(u.name, u.userId),
              ),
            ),
          ],
        ],

        GuestListItem(
          query: query,
          disabled: atMax || query.isEmpty,
          onTap: (!atMax && query.isNotEmpty) ? () => onAdd(query, null) : null,
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _FriendsErrorPanel extends StatelessWidget {
  final VoidCallback onRetry;

  const _FriendsErrorPanel({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: kColorOutline,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              s.participantLoadFailed,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                s.commonRetry,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: kColorOutline,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class FriendListItem extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isSelected;
  final bool disabled;
  final VoidCallback? onTap;

  const FriendListItem({
    super.key,
    required this.name,
    this.photoUrl,
    required this.isSelected,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(
            color: isSelected ? kColorPrimary.withAlpha(80) : kColorAmberBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            _Avatar(name: name, photoUrl: photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.spaceGrotesk(
                  color: disabled && !isSelected
                      ? kColorOutline
                      : kColorOnSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, color: kColorPrimary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    AppStrings.of(context).participantAdded,
                    style: GoogleFonts.spaceGrotesk(
                      color: kColorPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Icon(
                Icons.add,
                color: disabled ? kColorOutlineVariant : kColorOutline,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class UserListItem extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool disabled;
  final VoidCallback? onTap;

  const UserListItem({
    super.key,
    required this.name,
    this.photoUrl,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            _Avatar(name: name, photoUrl: photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.spaceGrotesk(
                  color: disabled ? kColorOutline : kColorOnSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.add,
              color: disabled ? kColorOutlineVariant : kColorOutline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class GuestListItem extends StatelessWidget {
  final String query;
  final bool disabled;
  final VoidCallback? onTap;

  const GuestListItem({
    super.key,
    required this.query,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled
                ? kColorOutlineVariant.withAlpha(80)
                : kColorOutlineVariant,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 18,
              color: disabled ? kColorOutlineVariant : kColorOutline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: query.isEmpty
                  ? Text(
                      s.participantGuestHint,
                      style: GoogleFonts.spaceGrotesk(
                        color: kColorOutlineVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : RichText(
                      text: TextSpan(
                        style: GoogleFonts.spaceGrotesk(
                          color: disabled
                              ? kColorOutlineVariant
                              : kColorOutline,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(text: s.participantAddGuestPrefix),
                          TextSpan(
                            text: '"$query"',
                            style: GoogleFonts.spaceGrotesk(
                              color: disabled
                                  ? kColorOutlineVariant
                                  : kColorOnSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: kColorSurfaceHighest,
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: kColorSurfaceHighest,
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          color: kColorOnSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
