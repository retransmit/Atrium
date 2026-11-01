import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_community_models.dart';
import '../slskd_providers.dart';

/// Modal bottom sheet allowing users to discover, search, and join Soulseek public chat rooms,
/// or enter a custom room name to join directly.
class SlskdDiscoverRoomsSheet extends ConsumerStatefulWidget {
  const SlskdDiscoverRoomsSheet({
    required this.instance,
    required this.onJoinRoom,
    super.key,
  });

  final Instance instance;
  final Future<bool> Function(String roomName) onJoinRoom;

  @override
  ConsumerState<SlskdDiscoverRoomsSheet> createState() => _SlskdDiscoverRoomsSheetState();
}

class _SlskdDiscoverRoomsSheetState extends ConsumerState<SlskdDiscoverRoomsSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customRoomController = TextEditingController();
  String _searchQuery = '';
  bool _isJoining = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customRoomController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin(String roomName) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty || _isJoining) return;

    setState(() => _isJoining = true);
    try {
      final bool joined = await widget.onJoinRoom(trimmed);
      if (joined && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final joinedRoomsAsync = ref.watch(slskdJoinedRoomNamesProvider(widget.instance));
    final availableRoomsAsync = ref.watch(slskdAvailableRoomsProvider(widget.instance));

    final Set<String> joinedSet = (joinedRoomsAsync.value ?? const <String>[]).toSet();
    final List<SlskdRoomInfo> allRooms = availableRoomsAsync.value ?? const <SlskdRoomInfo>[];

    // Filter rooms by search query
    final filteredRooms = _searchQuery.isEmpty
        ? allRooms
        : allRooms
            .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext ctx, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
              child: Row(
                children: <Widget>[
                  Icon(Icons.explore_rounded, color: colorScheme.primary),
                  const SizedBox(width: Insets.sm),
                  Text(
                    'Discover Chat Rooms',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.xs),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search public rooms...',
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: Insets.sm),
                ),
                leading: const Icon(Icons.search, size: 20),
                trailing: <Widget>[
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
                onChanged: (String val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            // Custom Room Join Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _customRoomController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Join custom room by name...',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: Insets.xs,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _handleJoin,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  FilledButton.tonal(
                    onPressed: _isJoining
                        ? null
                        : () => _handleJoin(_customRoomController.text),
                    child: const Text('Join'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Insets.xs),

            // Rooms List
            Expanded(
              child: (!availableRoomsAsync.hasValue && !availableRoomsAsync.hasError)
                  ? const Center(child: ExpressiveProgressIndicator())
                  // A failed load must not read as "No public rooms found".
                  : !availableRoomsAsync.hasValue
                      ? ErrorView(
                          title: 'Could not load rooms',
                          message: '${availableRoomsAsync.error}',
                          onRetry: () =>
                              ref.invalidate(slskdAvailableRoomsProvider(widget.instance)),
                        )
                  : filteredRooms.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.search_off_rounded, size: 40, color: colorScheme.outline),
                                const SizedBox(height: Insets.sm),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No public rooms found.'
                                      : 'No rooms matching "$_searchQuery".',
                                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: filteredRooms.length,
                          separatorBuilder: (BuildContext _, int index) => const Divider(
                            height: 1,
                            indent: 56,
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final room = filteredRooms[index];
                            final bool isJoined = joinedSet.contains(room.name);

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isJoined
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  room.isPrivate
                                      ? Icons.lock_outline_rounded
                                      : (isJoined ? Icons.forum_rounded : Icons.tag_rounded),
                                  size: 18,
                                  color: isJoined
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              title: Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      room.name,
                                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (room.isPrivate) ...<Widget>[
                                    const SizedBox(width: Insets.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PRIVATE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${room.userCount} members online',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: isJoined
                                  ? Chip(
                                      avatar: Icon(Icons.check_rounded, size: 14, color: colorScheme.primary),
                                      label: const Text('Joined'),
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                      side: BorderSide.none,
                                    )
                                  : FilledButton.tonal(
                                      onPressed: _isJoining ? null : () => _handleJoin(room.name),
                                      child: const Text('Join'),
                                    ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper function to display the Discover Rooms modal bottom sheet.
void showSlskdDiscoverRoomsSheet(
  BuildContext context, {
  required Instance instance,
  required Future<bool> Function(String roomName) onJoinRoom,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext _) => SlskdDiscoverRoomsSheet(
      instance: instance,
      onJoinRoom: onJoinRoom,
    ),
  );
}
