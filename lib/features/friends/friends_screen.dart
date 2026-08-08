import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/friend.dart';
import '../../shared/models/friend_request.dart';
import '../../shared/providers/friend_provider.dart';
import '../../shared/providers/repository_providers.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import 'friend_profile_screen.dart';
import 'friend_requests_screen.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class FriendsScreen extends ConsumerStatefulWidget {
  /// True when hosted as a bottom-nav tab (no back button); false when pushed
  /// as its own route (e.g. from the profile screen), which shows a back button.
  final bool embedded;

  const FriendsScreen({super.key, this.embedded = false});

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
        final results = await ref
            .read(friendRepositoryProvider)
            .searchUsers(expected);
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
      await ref.read(friendRepositoryProvider).sendFriendRequest(userId);
      ref.read(analyticsServiceProvider).logAddFriend();
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
    if (!ok && mounted) {
      _showSnackbar(AppStrings.of(context).friendsAcceptFailed);
    }
  }

  Future<void> _reject(FriendRequestSummary request) async {
    final ok = await ref
        .read(incomingRequestsProvider.notifier)
        .reject(request.requestId);
    if (!ok && mounted) {
      _showSnackbar(AppStrings.of(context).friendsDeclineFailed);
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

  String _friendlyError(Object e) {
    final s = AppStrings.of(context);
    final msg = e.toString().toLowerCase();
    if (msg.contains('already-exists')) {
      return s.friendsAlreadyExists;
    }
    return s.friendsSendFailed;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final query = _searchController.text.trim();
    final incomingCount =
        ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          s.friendsTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
        ),
        actions: [
          IconButton(
            tooltip: s.friendsRequestsTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
            ),
            icon: Badge(
              isLabelVisible: incomingCount > 0,
              label: Text('$incomingCount'),
              backgroundColor: context.colors.primary,
              textColor: context.colors.background,
              child: Icon(Icons.inbox_outlined, color: context.colors.primary),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
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
    final s = AppStrings.of(context);
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
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: context.colors.outline,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          s.friendsNoUsers,
          style: GoogleFonts.spaceGrotesk(
            color: context.colors.outline,
            fontSize: 14,
          ).kr,
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
    final s = AppStrings.of(context);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);
    final friendsAsync = ref.watch(friendListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Incoming requests — hidden while loading or on error; only shown when non-empty.
        if (incomingAsync.valueOrNull?.isNotEmpty == true) ...[
          _SectionLabel(s.friendsIncomingCount(incomingAsync.value!.length)),
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
          _SectionLabel(s.friendsPendingCount(outgoingAsync.value!.length)),
          ...outgoingAsync.value!.map((r) => _OutgoingRequestRow(request: r)),
          const SizedBox(height: 8),
        ],

        // Friends list — always shows the section header.
        _SectionLabel(s.friendsTitle),
        ...friendsAsync.when<List<Widget>>(
          loading: () => [const _SectionLoadingTile()],
          error: (err, _) => [
            _FriendErrorTile(onRetry: () => ref.invalidate(friendListProvider)),
          ],
          data: (friends) => friends.isEmpty
              ? [const _EmptyFriendsTile()]
              : friends
                    .map<Widget>(
                      (f) => _FriendRow(
                        friend: f,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FriendProfileScreen(
                              friendId: f.userId,
                              friendName: f.name,
                              friendPhotoUrl: f.photoUrl,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
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
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search_outlined,
              color: context.colors.outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                style: GoogleFonts.spaceGrotesk(
                  color: context.colors.onSurface,
                  fontSize: 14,
                ).kr,
                decoration: InputDecoration.collapsed(
                  hintText: AppStrings.of(context).friendsSearchHint,
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: context.colors.outline,
                    fontSize: 14,
                  ).kr,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, child) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: controller.clear,
                      child: Icon(
                        Icons.close,
                        color: context.colors.outline,
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
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.amberBorder),
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
                color: context.colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ).kr,
            ),
          ),
          _action(context),
        ],
      ),
    );
  }

  Widget _action(BuildContext context) {
    final s = AppStrings.of(context);
    if (isFriend) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: context.colors.primary, size: 13),
          const SizedBox(width: 4),
          Text(
            s.friendsStatusFriends,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ).kr,
          ),
        ],
      );
    }
    if (isSending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          color: context.colors.outline,
          strokeWidth: 1.5,
        ),
      );
    }
    if (isPending) {
      return Text(
        s.friendsStatusPending,
        style: GoogleFonts.spaceGrotesk(
          color: context.colors.outlineVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ).kr,
      );
    }
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.primary.withAlpha(140)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          s.friendsAdd,
          style: GoogleFonts.spaceGrotesk(
            color: context.colors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ).kr,
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
          color: context.colors.outline,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ).kr,
      ),
    );
  }
}

class _SectionLoadingTile extends StatelessWidget {
  const _SectionLoadingTile();

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
            onTap: onReject,
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

class _OutgoingRequestRow extends StatelessWidget {
  final FriendRequestSummary request;

  const _OutgoingRequestRow({required this.request});

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
          Text(
            s.friendsStatusPending,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outlineVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ).kr,
          ),
        ],
      ),
    );
  }
}

// ─── Friend row ───────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  final FriendSummary friend;
  final VoidCallback onTap;

  const _FriendRow({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          border: Border.all(color: context.colors.amberBorder),
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
                  color: context.colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ).kr,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.outlineVariant,
              size: 18,
            ),
          ],
        ),
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
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            s.friendsLoadFailed,
            style: GoogleFonts.spaceGrotesk(
              color: context.colors.outline,
              fontSize: 13,
            ).kr,
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              s.commonRetry,
              style: GoogleFonts.spaceGrotesk(
                color: context.colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ).kr,
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
        AppStrings.of(context).friendsEmpty,
        textAlign: TextAlign.center,
        style: GoogleFonts.newsreader(
          color: context.colors.outline,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ).kr,
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

String _timeAgo(AppStrings s, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return s.timeYearsAgo(diff.inDays ~/ 365);
  if (diff.inDays >= 30) return s.timeMonthsAgo(diff.inDays ~/ 30);
  if (diff.inDays >= 1) return s.timeDaysAgo(diff.inDays);
  if (diff.inHours >= 1) return s.timeHoursAgo(diff.inHours);
  if (diff.inMinutes >= 1) return s.timeMinutesAgo(diff.inMinutes);
  return s.timeJustNow;
}
