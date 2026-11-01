import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../browse/slskd_user_bio_sheet.dart';
import '../community/slskd_chat_bubble.dart';
import '../community/slskd_chat_composer.dart';
import '../community/slskd_conversation_tile.dart';
import '../community/slskd_discover_rooms_sheet.dart';
import '../community/slskd_room_card.dart';
import '../community/slskd_room_members_sheet.dart';
import '../models/slskd_community_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Community Tab in [SlskdHome] providing:
/// 1. Two-Tab Segregated Architecture: Direct Messages and Chat Rooms.
/// 2. Top-level dedicated SearchBars on each tab for instant filtering.
/// 3. Pull-to-refresh on each tab via [EasyRefresh].
/// 4. Contextual Floating Action Button (FAB):
///    - DMs tab: Start new 1-on-1 private conversation.
///    - Rooms tab: Discover & Join public rooms bottom sheet.
/// 5. Subviews for full-screen active room and 1-on-1 message threads.
class SlskdCommunityTab extends ConsumerStatefulWidget {
  const SlskdCommunityTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SlskdCommunityTab> createState() => _SlskdCommunityTabState();
}

class _SlskdCommunityTabState extends ConsumerState<SlskdCommunityTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _dmScrollController = ScrollController();
  final ScrollController _roomScrollController = ScrollController();
  final TextEditingController _dmSearchController = TextEditingController();
  final TextEditingController _roomSearchController = TextEditingController();
  String _dmSearchQuery = '';
  String _roomSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _dmScrollController.dispose();
    _roomScrollController.dispose();
    _dmSearchController.dispose();
    _roomSearchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Action Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _joinRoom(String roomName) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.joinRoom(roomName);
      if (!mounted) return false;
      ref.invalidate(slskdJoinedRoomNamesProvider(widget.instance));
      ref.read(slskdActiveConversationUsernameProvider(widget.instance).notifier).state = null;
      ref.read(slskdActiveRoomNameProvider(widget.instance).notifier).state = roomName;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to join room: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _leaveRoom(String roomName) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.leaveRoom(roomName);
      if (!mounted) return;
      ref.invalidate(slskdJoinedRoomNamesProvider(widget.instance));
      if (ref.read(slskdActiveRoomNameProvider(widget.instance)) == roomName) {
        ref.read(slskdActiveRoomNameProvider(widget.instance).notifier).state = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave room: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Whether the message went out, so the composer only clears on success.
  Future<bool> _sendRoomMessage(String roomName, String message) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.sendRoomMessage(roomName, message);
      if (!mounted) return true;
      ref.invalidate(slskdRoomMessagesProvider((widget.instance, roomName)));
      ref.invalidate(slskdRoomDetailProvider((widget.instance, roomName)));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _showSetTickerDialog(String roomName) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SetTickerDialog(roomName: roomName),
    );

    if (result != null && mounted) {
      try {
        final api = await ref.read(slskdApiProvider(widget.instance).future);
        await api.setRoomTicker(roomName, result);
        if (!mounted) return;
        ref.invalidate(slskdRoomDetailProvider((widget.instance, roomName)));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room ticker updated')),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update ticker: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Whether the message went out, so the composer only clears on success.
  Future<bool> _sendDirectMessage(String username, String message) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.sendPrivateMessage(username, message);
      if (!mounted) return true;
      ref.invalidate(slskdConversationMessagesProvider((widget.instance, username)));
      ref.invalidate(slskdConversationsProvider(widget.instance));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send DM: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _acknowledgeMessages(String username) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.acknowledgeAllMessages(username);
      if (!mounted) return;
      ref.invalidate(slskdConversationsProvider(widget.instance));
    } catch (_) {
      // Background acknowledgement errors ignored
    }
  }

  Future<void> _closeConversation(String username) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.closeConversation(username);
      if (!mounted) return;
      ref.invalidate(slskdConversationsProvider(widget.instance));
      if (ref.read(slskdActiveConversationUsernameProvider(widget.instance)) == username) {
        ref.read(slskdActiveConversationUsernameProvider(widget.instance).notifier).state = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close conversation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showNewChatDialog(BuildContext context) async {
    final String? target = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _NewChatDialog(),
    );
    if (target == null || !mounted) return;
    ref.read(slskdActiveRoomNameProvider(widget.instance).notifier).state = null;
    ref.read(slskdActiveConversationUsernameProvider(widget.instance).notifier).state = target;
  }

  // ---------------------------------------------------------------------------
  // Build Entry Point
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      slskdScrollToTopProvider((widget.instance, 3)),
      (previous, next) {
        if (next > 0) {
          final activeRoom =
              ref.read(slskdActiveRoomNameProvider(widget.instance));
          final activeConvo = ref
              .read(slskdActiveConversationUsernameProvider(widget.instance));
          if (activeRoom != null || activeConvo != null) {
            ref
                .read(slskdActiveRoomNameProvider(widget.instance).notifier)
                .state = null;
            ref
                .read(
                  slskdActiveConversationUsernameProvider(
                    widget.instance,
                  ).notifier,
                )
                .state = null;
            return;
          }
          final controller = _tabController.index == 0
              ? _dmScrollController
              : _roomScrollController;
          if (controller.hasClients) {
            controller.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
    );

    final String? activeRoom = ref.watch(slskdActiveRoomNameProvider(widget.instance));
    final String? activeConvo =
        ref.watch(slskdActiveConversationUsernameProvider(widget.instance));

    // 1. Subview: Active Room Chat
    if (activeRoom != null && activeRoom.isNotEmpty) {
      return _buildActiveRoomView(context, activeRoom);
    }

    // 2. Subview: Active 1-on-1 Direct Message Conversation
    if (activeConvo != null && activeConvo.isNotEmpty) {
      return _buildActiveConversationView(context, activeConvo);
    }

    // 3. Root View: Two-Tab Layout with Contextual FAB
    return _buildRootTabsView(context);
  }

  // ---------------------------------------------------------------------------
  // 1. Root Two-Tab Layout
  // ---------------------------------------------------------------------------

  Widget _buildRootTabsView(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final convosAsync = ref.watch(slskdConversationsProvider(widget.instance));
    final joinedRoomsAsync = ref.watch(slskdJoinedRoomNamesProvider(widget.instance));

    final int dmCount = convosAsync.value?.length ?? 0;
    final int joinedCount = joinedRoomsAsync.value?.length ?? 0;
    final bool isDmTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        leading: (widget.onOpenDrawer != null ||
                (Scaffold.maybeOf(context)?.hasDrawer ?? false))
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  if (widget.onOpenDrawer != null) {
                    widget.onOpenDrawer!();
                  } else {
                    Scaffold.maybeOf(context)?.openDrawer();
                  }
                },
              )
            : null,
        titleSpacing: widget.onOpenDrawer != null ? Insets.xs : Insets.md,
        title: SearchBar(
          controller: isDmTab ? _dmSearchController : _roomSearchController,
          hintText: isDmTab ? 'Search direct messages...' : 'Search joined rooms...',
          elevation: const WidgetStatePropertyAll<double>(0),
          backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: Insets.sm),
          ),
          leading: const Icon(Icons.search, size: 20),
          trailing: <Widget>[
            if (isDmTab ? _dmSearchQuery.isNotEmpty : _roomSearchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  if (isDmTab) {
                    _dmSearchController.clear();
                    setState(() => _dmSearchQuery = '');
                  } else {
                    _roomSearchController.clear();
                    setState(() => _roomSearchQuery = '');
                  }
                },
              ),
          ],
          onChanged: (String val) {
            setState(() {
              if (isDmTab) {
                _dmSearchQuery = val.trim();
              } else {
                _roomSearchQuery = val.trim();
              }
            });
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: <Widget>[
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  const SizedBox(width: Insets.xs),
                  Text('Direct Messages ($dmCount)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.forum_outlined, size: 18),
                  const SizedBox(width: Insets.xs),
                  Text('Chat Rooms ($joinedCount)'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildDirectMessagesTab(context),
          _buildChatRoomsTab(context),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              key: const ValueKey('new_dm_fab'),
              tooltip: 'New direct message',
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              onPressed: () => _showNewChatDialog(context),
              child: const Icon(Icons.edit_rounded),
            )
          : FloatingActionButton(
              key: const ValueKey('discover_rooms_fab'),
              tooltip: 'Discover public rooms',
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              onPressed: () => showSlskdDiscoverRoomsSheet(
                context,
                instance: widget.instance,
                onJoinRoom: _joinRoom,
              ),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Direct Messages View
  // ---------------------------------------------------------------------------

  Widget _buildDirectMessagesTab(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final convosAsync = ref.watch(slskdConversationsProvider(widget.instance));
    final List<SlskdConversation> conversations =
        convosAsync.value ?? const <SlskdConversation>[];

    final filteredConvos = _dmSearchQuery.isEmpty
        ? conversations
        : conversations.where((c) {
            final inName = c.username.toLowerCase().contains(_dmSearchQuery.toLowerCase());
            final inLast =
                c.lastMessage?.message.toLowerCase().contains(_dmSearchQuery.toLowerCase()) ??
                    false;
            return inName || inLast;
          }).toList();

    return EasyRefresh(
      onRefresh: () async {
        ref.invalidate(slskdConversationsProvider(widget.instance));
      },
      child: (!convosAsync.hasValue && !convosAsync.hasError)
          ? const Center(child: ExpressiveProgressIndicator())
          : !convosAsync.hasValue
              ? _buildLoadError(
                  title: 'Could not load direct messages',
                  error: convosAsync.error,
                  controller: _dmScrollController,
                  onRetry: () => ref.invalidate(slskdConversationsProvider(widget.instance)),
                )
          : filteredConvos.isEmpty
              ? ListView(
                  controller: _dmScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.md,
                      ),
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 40,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: Insets.sm),
                              Text(
                                _dmSearchQuery.isEmpty
                                    ? 'No direct messages yet.'
                                    : 'No direct messages matching "$_dmSearchQuery".',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              if (_dmSearchQuery.isEmpty) ...<Widget>[
                                const SizedBox(height: Insets.xs),
                                Text(
                                  'Tap the compose button below to message a peer.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.outline,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _dmScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  itemCount: filteredConvos.length,
                  itemBuilder: (BuildContext context, int index) {
                    final conversation = filteredConvos[index];
                    return SlskdConversationTile(
                      key: ValueKey('convo_${conversation.username}'),
                      conversation: conversation,
                      onTap: () {
                        ref
                            .read(slskdActiveRoomNameProvider(widget.instance).notifier)
                            .state = null;
                        ref
                            .read(slskdActiveConversationUsernameProvider(widget.instance)
                                .notifier)
                            .state = conversation.username;
                        if (conversation.unAcknowledgedMessageCount > 0) {
                          _acknowledgeMessages(conversation.username);
                        }
                      },
                      onClose: () => _closeConversation(conversation.username),
                    );
                  },
                ),
    );
  }

  /// A list that failed to load, kept scrollable so pull-to-refresh still
  /// works. Without it the failure would read as an empty list.
  Widget _buildLoadError({
    required String title,
    required Object? error,
    required ScrollController controller,
    required VoidCallback onRetry,
  }) {
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        ErrorView(title: title, message: '$error', onRetry: onRetry),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Chat Rooms View
  // ---------------------------------------------------------------------------

  Widget _buildChatRoomsTab(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final joinedRoomsAsync = ref.watch(slskdJoinedRoomNamesProvider(widget.instance));
    final availableRoomsAsync = ref.watch(slskdAvailableRoomsProvider(widget.instance));

    final Set<String> joinedNames = (joinedRoomsAsync.value ?? const <String>[]).toSet();
    final List<SlskdRoomInfo> allRooms = availableRoomsAsync.value ?? const <SlskdRoomInfo>[];

    final filteredJoined = joinedNames
        .where((name) => name.toLowerCase().contains(_roomSearchQuery.toLowerCase()))
        .toList();

    return EasyRefresh(
      onRefresh: () async {
        ref.invalidate(slskdJoinedRoomNamesProvider(widget.instance));
        ref.invalidate(slskdAvailableRoomsProvider(widget.instance));
      },
      child: (!joinedRoomsAsync.hasValue && !joinedRoomsAsync.hasError)
          ? const Center(child: ExpressiveProgressIndicator())
          : !joinedRoomsAsync.hasValue
              ? _buildLoadError(
                  title: 'Could not load your rooms',
                  error: joinedRoomsAsync.error,
                  controller: _roomScrollController,
                  onRetry: () => ref.invalidate(slskdJoinedRoomNamesProvider(widget.instance)),
                )
          : filteredJoined.isEmpty
              ? ListView(
                  controller: _roomScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.md,
                      ),
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.forum_outlined,
                                size: 40,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: Insets.sm),
                              Text(
                                _roomSearchQuery.isEmpty
                                    ? 'No chat rooms joined yet.'
                                    : 'No joined rooms matching "$_roomSearchQuery".',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              if (_roomSearchQuery.isEmpty) ...<Widget>[
                                const SizedBox(height: Insets.xs),
                                Text(
                                  'Tap + below to discover and join public rooms.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.outline,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _roomScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  itemCount: filteredJoined.length,
                  itemBuilder: (BuildContext context, int index) {
                    final roomName = filteredJoined[index];
                    final roomInfo = allRooms.firstWhere(
                      (r) => r.name == roomName,
                      orElse: () => SlskdRoomInfo(name: roomName),
                    );
                    return SlskdRoomCard(
                      key: ValueKey('joined_$roomName'),
                      name: roomName,
                      userCount: roomInfo.userCount,
                      isJoined: true,
                      isPrivate: roomInfo.isPrivate,
                      onTap: () {
                        ref
                            .read(slskdActiveConversationUsernameProvider(widget.instance).notifier)
                            .state = null;
                        ref
                            .read(slskdActiveRoomNameProvider(widget.instance).notifier)
                            .state = roomName;
                      },
                      onLeave: () => _leaveRoom(roomName),
                    );
                  },
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Active Room Chat View
  // ---------------------------------------------------------------------------

  Widget _buildActiveRoomView(BuildContext context, String roomName) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final roomDetailAsync = ref.watch(slskdRoomDetailProvider((widget.instance, roomName)));
    final messagesAsync = ref.watch(slskdRoomMessagesProvider((widget.instance, roomName)));
    final usersAsync = ref.watch(slskdRoomUsersProvider((widget.instance, roomName)));

    final int userCount = usersAsync.value?.length ?? roomDetailAsync.value?.userCount ?? 0;
    final List<SlskdRoomMessage> messages = messagesAsync.value ?? const <SlskdRoomMessage>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(slskdActiveRoomNameProvider(widget.instance).notifier).state = null;
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              roomName,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '$userCount members online',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'View active members',
            icon: const Icon(Icons.people_outline_rounded),
            onPressed: () {
              showSlskdRoomMembersSheet(
                context,
                instance: widget.instance,
                roomName: roomName,
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh messages',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(slskdRoomMessagesProvider((widget.instance, roomName)));
              ref.invalidate(slskdRoomUsersProvider((widget.instance, roomName)));
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Room options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'ticker') {
                _showSetTickerDialog(roomName);
              } else if (val == 'members') {
                showSlskdRoomMembersSheet(
                  context,
                  instance: widget.instance,
                  roomName: roomName,
                );
              } else if (val == 'leave') {
                _leaveRoom(roomName);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'ticker',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.campaign_outlined),
                  title: Text('Set Room Ticker'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'members',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.people_outline_rounded),
                  title: Text('Room Members'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'leave',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.exit_to_app_rounded, color: colorScheme.error),
                  title: Text('Leave Room', style: TextStyle(color: colorScheme.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Messages Feed
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: ExpressiveProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Text(
                      'Failed to load room messages: $error',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
                data: (_) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.forum_outlined, size: 48, color: colorScheme.outline),
                          const SizedBox(height: Insets.sm),
                          Text(
                            'No messages in #$roomName yet.',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Say hi to start the conversation!',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    );
                  }

                  // Reversed so the feed opens on the newest message and a
                  // sent message lands in view. slskd lists oldest first.
                  return ListView.builder(
                    reverse: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int reversedIndex) {
                      final int index = messages.length - 1 - reversedIndex;
                      final msg = messages[index];
                      return SlskdChatBubble.room(
                        key: ValueKey(
                          'msg_${msg.username}_${msg.timestamp.millisecondsSinceEpoch}_$index',
                        ),
                        roomMessage: msg,
                        instance: widget.instance,
                      );
                    },
                  );
                },
              ),
            ),

            // Sticky Bottom Composer
            SlskdChatComposer(
              hintText: 'Message $roomName...',
              onSend: (String text) => _sendRoomMessage(roomName, text),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Active 1-on-1 Direct Message View
  // ---------------------------------------------------------------------------

  Widget _buildActiveConversationView(BuildContext context, String username) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final messagesAsync =
        ref.watch(slskdConversationMessagesProvider((widget.instance, username)));
    final List<SlskdPrivateMessage> messages =
        messagesAsync.value ?? const <SlskdPrivateMessage>[];

    final userStatusAsync =
        ref.watch(slskdUserStatusProvider((widget.instance, username)));
    final userStatus = userStatusAsync.value;
    // Watched, not read on tap: nothing else keeps this autoDispose
    // provider alive, so a read would only ever see it loading.
    final userInfo = ref
        .watch(slskdUserInfoProvider((widget.instance, username)))
        .value;
    final bool isOnline = userStatus?.isOnline ?? false;
    final bool isAway = userStatus?.isAway ?? false;
    final String statusText = !userStatusAsync.hasValue
        ? 'Connecting...'
        : (isOnline ? 'Online' : (isAway ? 'Away' : 'Offline'));
    final Color statusColor = slskdPresenceColor(
      colorScheme,
      isOnline: isOnline,
      isAway: isAway,
    );

    ref.listen(slskdConversationMessagesProvider((widget.instance, username)), (prev, next) {
      final hasUnacked = next.value
              ?.any((m) => !m.isAcknowledged && m.direction == MessageDirection.inbound) ??
          false;
      if (hasUnacked) {
        _acknowledgeMessages(username);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(slskdActiveConversationUsernameProvider(widget.instance).notifier).state =
                null;
          },
        ),
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Browse $username shares',
            icon: const Icon(Icons.folder_shared_outlined),
            onPressed: () {
              ref.read(slskdBrowseUsernameProvider(widget.instance).notifier).state = username;
              // Start at this peer's root, not inside the last peer's folder.
              ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state =
                  const <String>[];
              ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 2; // Jump to Browse tab
            },
          ),
          IconButton(
            tooltip: 'User profile bio',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showSlskdUserBioSheet(
                context,
                username: username,
                userInfo: userInfo,
                userStatus: userStatus,
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh messages',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(slskdConversationMessagesProvider((widget.instance, username)));
            },
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Messages Feed
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: ExpressiveProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Text(
                      'Failed to load direct messages: $error',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
                data: (_) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: colorScheme.outline),
                          const SizedBox(height: Insets.sm),
                          Text(
                            'No conversation history with $username yet.',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Send a private message to get started!',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    );
                  }

                  // Reversed so the thread opens on the newest message and a
                  // sent message lands in view. slskd lists oldest first.
                  return ListView.builder(
                    reverse: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int reversedIndex) {
                      final int index = messages.length - 1 - reversedIndex;
                      final msg = messages[index];
                      return SlskdChatBubble.direct(
                        key: ValueKey('dm_${msg.id}_$index'),
                        privateMessage: msg,
                        instance: widget.instance,
                      );
                    },
                  );
                },
              ),
            ),

            // Sticky Bottom Composer
            SlskdChatComposer(
              hintText: 'Message $username...',
              onSend: (String text) => _sendDirectMessage(username, text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a peer's username and pops it. The dialog owns its controller,
/// so the controller lives until the dialog's exit animation has finished.
class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _userCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Direct Message'),
      content: TextField(
        controller: _userCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Peer Username',
          hintText: 'Enter Soulseek user...',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final target = _userCtrl.text.trim();
            if (target.isEmpty) return;
            Navigator.of(context).pop(target);
          },
          child: const Text('Start Chat'),
        ),
      ],
    );
  }
}

class _SetTickerDialog extends StatefulWidget {
  const _SetTickerDialog({required this.roomName});

  final String roomName;

  @override
  State<_SetTickerDialog> createState() => _SetTickerDialogState();
}

class _SetTickerDialogState extends State<_SetTickerDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Ticker for #${widget.roomName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Announcement / Ticker',
          hintText: 'Enter room ticker message',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.of(context).pop(text);
          },
          child: const Text('Set Ticker'),
        ),
      ],
    );
  }
}
