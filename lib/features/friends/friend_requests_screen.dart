import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/friend_request.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/theme/app_theme.dart';

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
    if (!ok && mounted) _showSnackbar('Failed to accept. Try again.');
  }

  Future<void> _reject(String requestId) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .reject(requestId);
    if (!ok && mounted) _showSnackbar('Failed to decline. Try again.');
  }

  Future<void> _cancel(String requestId) async {
    final ok = await ref
        .read(outgoingRequestsProvider.notifier)
        .cancel(requestId);
    if (!ok && mounted) _showSnackbar('Failed to cancel. Try again.');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.spaceGrotesk(color: kColorOnSurface),
        ),
        backgroundColor: kColorSurfaceHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    final incomingCount = incomingAsync.valueOrNull?.length;
    final outgoingCount = outgoingAsync.valueOrNull?.length;

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'REQUESTS',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionLabel(
            incomingCount != null && incomingCount > 0
                ? 'INCOMING ($incomingCount)'
                : 'INCOMING',
          ),
          ...incomingAsync.when(
            loading: () => [const _LoadingTile()],
            error: (_, _) => [
              const _MessageTile('Could not load incoming requests.'),
            ],
            data: (requests) => requests.isEmpty
                ? [const _MessageTile('No incoming requests.')]
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
                ? 'SENT ($outgoingCount)'
                : 'SENT',
          ),
          ...outgoingAsync.when(
            loading: () => [const _LoadingTile()],
            error: (_, _) => [
              const _MessageTile('Could not load sent requests.'),
            ],
            data: (requests) => requests.isEmpty
                ? [const _MessageTile('No sent requests.')]
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
          color: kColorOutline,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
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
          _Avatar(name: request.name, photoUrl: request.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _timeAgo(request.createdAt),
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kColorPrimary.withAlpha(20),
                border: Border.all(color: kColorPrimary.withAlpha(100)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ACCEPT',
                style: GoogleFonts.spaceGrotesk(
                  color: kColorPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onDecline,
            child: Text(
              'DECLINE',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
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
          _Avatar(name: request.name, photoUrl: request.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _timeAgo(request.createdAt),
                  style: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOutline,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
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
        style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 13),
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
