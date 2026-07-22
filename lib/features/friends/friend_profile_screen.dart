import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/friend_profile.dart';
import '../../shared/models/play.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../plays/play_detail_page.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;

  const FriendProfileScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
  });

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  late Future<FriendProfile> _profileFuture;
  late Future<List<PlaySummary>> _sharedPlaysFuture;
  bool _unfriending = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = ref
        .read(friendRepositoryProvider)
        .getFriendProfileDirect(widget.friendId);
    _sharedPlaysFuture = ref
        .read(playRepositoryProvider)
        .fetchSharedPlays(widget.friendId);
  }

  Future<void> _unfriend() async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorSurfaceHigh,
        title: Text(
          s.friendUnfriendTitle(widget.friendName),
          style: GoogleFonts.newsreader(color: kColorOnSurface),
        ),
        content: Text(
          s.friendUnfriendBody,
          style: GoogleFonts.spaceGrotesk(
            color: kColorOnSurfaceVariant,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              s.commonCancel,
              style: GoogleFonts.spaceGrotesk(color: kColorOutline),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              s.friendUnfriendAction,
              style: GoogleFonts.spaceGrotesk(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _unfriending = true);
    try {
      await ref.read(friendRepositoryProvider).removeFriend(widget.friendId);
      if (!mounted) return;
      ref.invalidate(friendListProvider);
      Navigator.of(context).pop();
    } catch (e, st) {
      dev.log(
        'removeFriend failed',
        error: e,
        stackTrace: st,
        name: 'FriendProfileScreen',
      );
      if (!mounted) return;
      setState(() => _unfriending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).friendUnfriendFailed,
            style: GoogleFonts.spaceGrotesk(color: kColorOnSurface),
          ),
          backgroundColor: kColorSurfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: kColorAppBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.profileTitle,
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
      body: FutureBuilder<FriendProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: kColorOutline,
                  strokeWidth: 1.5,
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                s.friendProfileLoadFailed,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOutline,
                  fontSize: 14,
                ),
              ),
            );
          }

          final profile = snapshot.data!;
          return _ProfileBody(
            friendId: widget.friendId,
            profile: profile,
            sharedPlaysFuture: _sharedPlaysFuture,
            unfriending: _unfriending,
            onUnfriend: _unfriend,
          );
        },
      ),
    );
  }
}

// ─── Body (separated so the FutureBuilder stays thin) ────────────────────────

class _ProfileBody extends StatelessWidget {
  final String friendId;
  final FriendProfile profile;
  final Future<List<PlaySummary>> sharedPlaysFuture;
  final bool unfriending;
  final VoidCallback onUnfriend;

  const _ProfileBody({
    required this.friendId,
    required this.profile,
    required this.sharedPlaysFuture,
    required this.unfriending,
    required this.onUnfriend,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final winPct = profile.totalGamesPlayed == 0
        ? '—'
        : '${(profile.winRate * 100).round()}%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      children: [
        // ── Avatar & name ──────────────────────────────────────────────────
        Center(
          child: _Avatar(name: profile.name, photoUrl: profile.photoUrl),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            profile.name,
            style: GoogleFonts.newsreader(
              color: kColorOnSurface,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (profile.lastPlayedAt != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              s.friendLastPlayed(_timeAgo(s, profile.lastPlayedAt!)),
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),

        // ── Stats row ──────────────────────────────────────────────────────
        _SectionLabel(s.friendStats),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${profile.totalGamesPlayed}',
                label: s.homeStatPlays,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: '${profile.totalWins}',
                label: s.homeStatWins,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: winPct, label: s.homeStatWinRate),
            ),
          ],
        ),

        // ── Top games ──────────────────────────────────────────────────────
        if (profile.topGames.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(s.friendMostPlayed),
          const SizedBox(height: 8),
          ...profile.topGames.map((g) => _GameRow(game: g)),
        ],

        // ── Played together ────────────────────────────────────────────────
        const SizedBox(height: 28),
        _SectionLabel(s.friendPlayedTogether),
        const SizedBox(height: 8),
        _SharedPlays(future: sharedPlaysFuture),

        // ── Unfriend ───────────────────────────────────────────────────────
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: unfriending ? null : onUnfriend,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withAlpha(120)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            child: unfriending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.redAccent,
                      strokeWidth: 1.5,
                    ),
                  )
                : Text(s.friendUnfriendCaps),
          ),
        ),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        color: kColorOutline,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.newsreader(
              color: kColorPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: kColorOutline,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final FriendGameStat game;
  const _GameRow({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              game.gameName,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            AppStrings.of(
              context,
            ).friendGameStat(game.playCount, game.winCount),
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SharedPlays extends StatelessWidget {
  final Future<List<PlaySummary>> future;

  const _SharedPlays({required this.future});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return FutureBuilder<List<PlaySummary>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
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
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            s.friendSharedPlaysError,
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 13),
          );
        }
        final plays = snapshot.data!;
        if (plays.isEmpty) {
          return Text(
            s.friendNoSharedPlays,
            style: GoogleFonts.newsreader(
              color: kColorOutline,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.friendSharedCount(plays.length),
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...plays.map((p) => _SharedPlayRow(play: p)),
          ],
        );
      },
    );
  }
}

class _SharedPlayRow extends StatelessWidget {
  final PlaySummary play;

  const _SharedPlayRow({required this.play});

  static const _months = [
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

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PlayDetailPage(initialData: play)),
      ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    play.gameName,
                    style: GoogleFonts.newsreader(
                      color: kColorOnSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(play.playedAt),
                    style: GoogleFonts.spaceGrotesk(
                      color: kColorOutline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppStrings.of(context).playersCount(play.participantCount),
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: kColorOutlineVariant,
              size: 18,
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
        radius: 40,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: kColorSurfaceHighest,
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 40,
      backgroundColor: kColorSurfaceHighest,
      child: Text(
        initial,
        style: GoogleFonts.newsreader(
          color: kColorPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Utilities ────────────────────────────────────────────────────────────────

String _timeAgo(AppStrings s, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return s.timeYearsAgo(diff.inDays ~/ 365);
  if (diff.inDays >= 30) return s.timeMonthsAgo(diff.inDays ~/ 30);
  if (diff.inDays >= 1) return s.timeDaysAgo(diff.inDays);
  if (diff.inHours >= 1) return s.timeHoursAgo(diff.inHours);
  if (diff.inMinutes >= 1) return s.timeMinutesAgo(diff.inMinutes);
  return s.timeJustNow;
}
