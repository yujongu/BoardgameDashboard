import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/friend.dart';
import '../../shared/models/friend_request.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/repositories/friend_repository.dart';
import '../../shared/theme/app_theme.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult> _searchResults = [];
  bool _loadingSearch = false;
  final Set<String> _pendingSends = {};
  // Optimistic: userIds sent this session, before outgoingRequestsProvider re-fetches.
  final Set<String> _sentThisSession = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    final trimmed = _searchController.text.trim();
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _loadingSearch = false;
      });
      return;
    }

    setState(() => _loadingSearch = true);

    final expected = trimmed;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await FriendRepository.instance.searchUsers(expected);
        if (mounted && _searchController.text.trim() == expected) {
          setState(() {
            _searchResults = results;
            _loadingSearch = false;
          });
        }
      } catch (_) {
        if (mounted && _searchController.text.trim() == expected) {
          setState(() => _loadingSearch = false);
        }
      }
    });
  }

  Future<void> _sendRequest(String userId) async {
    setState(() => _pendingSends.add(userId));
    try {
      await FriendRepository.instance.sendFriendRequest(userId);
      if (!mounted) return;
      setState(() {
        _pendingSends.remove(userId);
        _sentThisSession.add(userId);
      });
      ref.invalidate(outgoingRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingSends.remove(userId));
      _showSnackbar(_friendlyError(e));
    }
  }

  Future<void> _accept(FriendRequestSummary request) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .accept(request.requestId);
    if (!ok && mounted) _showSnackbar('Failed to accept. Try again.');
  }

  Future<void> _reject(FriendRequestSummary request) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .reject(request.requestId);
    if (!ok && mounted) _showSnackbar('Failed to decline. Try again.');
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

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already-exists')) {
      return 'Already friends or request already pending.';
    }
    return 'Could not send request. Try again.';
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'FRIENDS',
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
      body: Column(
        children: [
          _SearchField(controller: _searchController),
          Expanded(
            child: query.isNotEmpty ? _buildSearchView() : _buildSectionsView(),
          ),
        ],
      ),
    );
  }

  // ─── Search results view ────────────────────────────────────────────────────

  Widget _buildSearchView() {
    // Always watch so these providers don't dispose mid-search.
    final friendIds =
        ref
            .watch(friendListProvider)
            .valueOrNull
            ?.map((f) => f.userId)
            .toSet() ??
        {};
    final outgoingIds =
        ref
            .watch(outgoingRequestsProvider)
            .valueOrNull
            ?.map((r) => r.userId)
            .toSet() ??
        {};
    final pendingIds = outgoingIds.union(_sentThisSession);

    if (_loadingSearch) {
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

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: _searchResults.map((u) {
        final isFriend = friendIds.contains(u.userId);
        final isPending = pendingIds.contains(u.userId);
        final isSending = _pendingSends.contains(u.userId);
        return _SearchResultRow(
          name: u.name,
          photoUrl: u.photoUrl,
          isFriend: isFriend,
          isPending: isPending,
          isSending: isSending,
          onAdd: (isFriend || isPending || isSending)
              ? null
              : () => _sendRequest(u.userId),
        );
      }).toList(),
    );
  }

  // ─── Sections view (no query) ───────────────────────────────────────────────

  Widget _buildSectionsView() {
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);
    final friendsAsync = ref.watch(friendListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Incoming requests — hidden while loading or on error; only shown when non-empty.
        if (incomingAsync.valueOrNull?.isNotEmpty == true) ...[
          _SectionLabel('INCOMING (${incomingAsync.value!.length})'),
          ...incomingAsync.value!.map(
            (r) => _IncomingRequestRow(
              request: r,
              onAccept: () => _accept(r),
              onReject: () => _reject(r),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Outgoing / pending — hidden while loading or on error; only shown when non-empty.
        if (outgoingAsync.valueOrNull?.isNotEmpty == true) ...[
          _SectionLabel('PENDING (${outgoingAsync.value!.length})'),
          ...outgoingAsync.value!.map((r) => _OutgoingRequestRow(request: r)),
          const SizedBox(height: 8),
        ],

        // Friends list — always shows the section header.
        const _SectionLabel('FRIENDS'),
        ...friendsAsync.when<List<Widget>>(
          loading: () => [const _SectionLoadingTile()],
          error: (err, _) => [
            _FriendErrorTile(
              onRetry: () => ref.read(friendListProvider.notifier).retry(),
            ),
          ],
          data: (friends) => friends.isEmpty
              ? [const _EmptyFriendsTile()]
              : friends.map<Widget>((f) => _FriendRow(friend: f)).toList(),
        ),
      ],
    );
  }
}

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: kColorSurfaceHigh,
          border: Border.all(color: kColorAmberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_search_outlined,
              color: kColorOutline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                style: GoogleFonts.spaceGrotesk(
                  color: kColorOnSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Search to add friends…',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: kColorOutline,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, child) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: controller.clear,
                      child: const Icon(
                        Icons.close,
                        color: kColorOutline,
                        size: 16,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search result row ────────────────────────────────────────────────────────

class _SearchResultRow extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isFriend;
  final bool isPending;
  final bool isSending;
  final VoidCallback? onAdd;

  const _SearchResultRow({
    required this.name,
    this.photoUrl,
    required this.isFriend,
    required this.isPending,
    required this.isSending,
    this.onAdd,
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
          _Avatar(name: name, photoUrl: photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _action(),
        ],
      ),
    );
  }

  Widget _action() {
    if (isFriend) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: kColorPrimary, size: 13),
          const SizedBox(width: 4),
          Text(
            'FRIENDS',
            style: GoogleFonts.spaceGrotesk(
              color: kColorPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
    }
    if (isSending) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          color: kColorOutline,
          strokeWidth: 1.5,
        ),
      );
    }
    if (isPending) {
      return Text(
        'PENDING',
        style: GoogleFonts.spaceGrotesk(
          color: kColorOutlineVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
    }
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: kColorPrimary.withAlpha(140)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'ADD',
          style: GoogleFonts.spaceGrotesk(
            color: kColorPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ─── Section chrome ───────────────────────────────────────────────────────────

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

class _SectionLoadingTile extends StatelessWidget {
  const _SectionLoadingTile();

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

// ─── Incoming request row ─────────────────────────────────────────────────────

class _IncomingRequestRow extends StatelessWidget {
  final FriendRequestSummary request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingRequestRow({
    required this.request,
    required this.onAccept,
    required this.onReject,
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
            onTap: onReject,
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

class _OutgoingRequestRow extends StatelessWidget {
  final FriendRequestSummary request;

  const _OutgoingRequestRow({required this.request});

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
          Text(
            'PENDING',
            style: GoogleFonts.spaceGrotesk(
              color: kColorOutlineVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend row ───────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  final FriendSummary friend;

  const _FriendRow({required this.friend});

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
          _Avatar(name: friend.name, photoUrl: friend.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              friend.name,
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _FriendErrorTile extends StatelessWidget {
  final VoidCallback onRetry;

  const _FriendErrorTile({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Could not load friends.',
            style: GoogleFonts.spaceGrotesk(color: kColorOutline, fontSize: 13),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'RETRY',
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
    );
  }
}

class _EmptyFriendsTile extends StatelessWidget {
  const _EmptyFriendsTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        'No friends yet.\nSearch above to add someone.',
        textAlign: TextAlign.center,
        style: GoogleFonts.newsreader(
          color: kColorOutline,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ─── Shared utilities ─────────────────────────────────────────────────────────

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

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}
