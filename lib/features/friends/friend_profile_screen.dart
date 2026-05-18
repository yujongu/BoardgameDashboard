import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/friend_profile.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/repositories/friend_repository.dart';
import '../../shared/theme/app_theme.dart';

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
  bool _unfriending = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = FriendRepository.instance.getFriendProfileDirect(
      widget.friendId,
    );
  }

  Future<void> _unfriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorSurfaceHigh,
        title: Text(
          'Unfriend ${widget.friendName}?',
          style: GoogleFonts.newsreader(color: kColorOnSurface),
        ),
        content: Text(
          'You will no longer appear in each other\'s friends list.',
          style: GoogleFonts.spaceGrotesk(
            color: kColorOnSurfaceVariant,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: kColorOutline),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Unfriend',
              style: GoogleFonts.spaceGrotesk(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _unfriending = true);
    try {
      await FriendRepository.instance.removeFriend(widget.friendId);
      if (!mounted) return;
      ref.invalidate(friendListProvider);
      Navigator.of(context).pop();
    } catch (e, s) {
      dev.log(
        'removeFriend failed',
        error: e,
        stackTrace: s,
        name: 'FriendProfileScreen',
      );
      if (!mounted) return;
      setState(() => _unfriending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to unfriend. Try again.',
            style: GoogleFonts.spaceGrotesk(color: kColorOnSurface),
          ),
          backgroundColor: kColorSurfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: kColorAppBarBackground,
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
                'Could not load profile.',
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
  final bool unfriending;
  final VoidCallback onUnfriend;

  const _ProfileBody({
    required this.friendId,
    required this.profile,
    required this.unfriending,
    required this.onUnfriend,
  });

  @override
  Widget build(BuildContext context) {
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
              'Last played ${_timeAgo(profile.lastPlayedAt!)}',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),

        // ── Stats row ──────────────────────────────────────────────────────
        _SectionLabel('STATS'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${profile.totalGamesPlayed}',
                label: 'PLAYS',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: '${profile.totalWins}', label: 'WINS'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: winPct, label: 'WIN RATE'),
            ),
          ],
        ),

        // ── Top games ──────────────────────────────────────────────────────
        if (profile.topGames.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel('MOST PLAYED'),
          const SizedBox(height: 8),
          ...profile.topGames.map((g) => _GameRow(game: g)),
        ],

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
                : const Text('UNFRIEND'),
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
            '${game.playCount} plays · ${game.winCount} wins',
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 11),
          ),
        ],
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

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}
