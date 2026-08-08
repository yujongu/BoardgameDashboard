import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/friend_request.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  Future<void> _accept(String requestId) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .accept(requestId);
    if (!ok && mounted) {
      _showSnackbar(AppStrings.of(context).friendsAcceptFailed);
    }
  }

  Future<void> _reject(String requestId) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .reject(requestId);
    if (!ok && mounted) {
      _showSnackbar(AppStrings.of(context).friendsDeclineFailed);
    }
  }

  Future<void> _cancel(String requestId) async {
    final ok = await ref
        .read(outgoingRequestsProvider.notifier)
        .cancel(requestId);
    if (!ok && mounted) {
      _showSnackbar(AppStrings.of(context).friendsCancelFailed);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.spaceGrotesk(color: context.colors.onSurface).kr,
        ),
        backgroundColor: context.colors.surfaceHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    final incomingCount = incomingAsync.valueOrNull?.length;
    final outgoingCount = outgoingAsync.valueOrNull?.length;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.friendsRequestsTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionLabel(
            incomingCount != null && incomingCount > 0
                ? s.friendsIncomingCount(incomingCount)
                : s.friendsIncoming,
          ),
          ...incomingAsync.when(
            loading: () => [const _LoadingTile()],
            error: (_, _) => [_MessageTile(s.friendsIncomingLoadFailed)],
            data: (requests) => requests.isEmpty
                ? [_MessageTile(s.friendsNoIncoming)]
                : requests
                      .map(
                        (r) => _IncomingRow(
                          request: r,
                          onAccept: () => _accept(r.requestId),
                          onDecline: () => _reject(r.requestId),
                        ),
                      )
                      .toList(),
          ),
          const SizedBox(height: 8),
          _SectionLabel(
            outgoingCount != null && outgoingCount > 0
                ? s.friendsSentCount(outgoingCount)
                : s.friendsSent,
          ),
          ...outgoingAsync.when(
            loading: () => [const _LoadingTile()],
            error: (_, _) => [_MessageTile(s.friendsSentLoadFailed)],
            data: (requests) => requests.isEmpty
                ? [_MessageTile(s.friendsNoSent)]
                : requests
                      .map(
                        (r) => _OutgoingRow(
                          request: r,
                          onCancel: () => _cancel(r.requestId),
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.outline,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ).kr,
      ),
    );
  }
}

// ─── Incoming request row ─────────────────────────────────────────────────────

class _IncomingRow extends StatelessWidget {
  final FriendRequestSummary request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingRow({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _Avatar(name: request.name, photoUrl: request.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ).kr,
                ),
                Text(
                  _timeAgo(s, request.createdAt),
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 11,
                  ).kr,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.primary.withAlpha(20),
                border: Border.all(
                  color: context.colors.primary.withAlpha(100),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                s.friendsAccept,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ).kr,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onDecline,
            child: Text(
              s.friendsDecline,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ).kr,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Outgoing request row ─────────────────────────────────────────────────────

class _OutgoingRow extends StatelessWidget {
  final FriendRequestSummary request;
  final VoidCallback onCancel;

  const _OutgoingRow({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _Avatar(name: request.name, photoUrl: request.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ).kr,
                ),
                Text(
                  _timeAgo(s, request.createdAt),
                  style: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 11,
                  ).kr,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Text(
              s.commonCancelCaps,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.outline,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ).kr,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared tiles ─────────────────────────────────────────────────────────────

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: context.colors.outline,
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final String text;

  const _MessageTile(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.outline,
          fontSize: 13,
        ).kr,
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

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
        backgroundColor: context.colors.surfaceHighest,
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: context.colors.surfaceHighest,
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ).kr,
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
