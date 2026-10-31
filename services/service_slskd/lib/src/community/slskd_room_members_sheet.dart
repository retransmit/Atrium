import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_browse_models.dart';
import '../models/slskd_community_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_peer_action_sheet.dart';

/// Shows the bottom sheet listing all users in the active room.
Future<void> showSlskdRoomMembersSheet(
  BuildContext context, {
  required Instance instance,
  required String roomName,
  List<SlskdUserPresence>? initialMembers,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (BuildContext _) => SlskdRoomMembersSheet(
      instance: instance,
      roomName: roomName,
      initialMembers: initialMembers,
    ),
  );
}

/// Modal bottom sheet displaying online room members with presence dots and 1-tap peer shortcuts.
class SlskdRoomMembersSheet extends ConsumerStatefulWidget {
  const SlskdRoomMembersSheet({
    required this.instance,
    required this.roomName,
    this.initialMembers,
    super.key,
  });

  final Instance instance;
  final String roomName;
  final List<SlskdUserPresence>? initialMembers;

  @override
  ConsumerState<SlskdRoomMembersSheet> createState() => _SlskdRoomMembersSheetState();
}

class _SlskdRoomMembersSheetState extends ConsumerState<SlskdRoomMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showInviteMemberDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _InviteMemberDialog(roomName: widget.roomName),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final api = await ref.read(slskdApiProvider(widget.instance).future);
        await api.addPrivateRoomMember(widget.roomName, result);
        if (!mounted) return;
        ref.invalidate(slskdRoomUsersProvider((widget.instance, widget.roomName)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invited $result to #${widget.roomName}')),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to invite member: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final usersAsync = ref.watch(slskdRoomUsersProvider((widget.instance, widget.roomName)));
    final List<SlskdUserPresence> members =
        usersAsync.value ?? widget.initialMembers ?? const <SlskdUserPresence>[];

    final filtered = _filterQuery.isEmpty
        ? members
        : members.where((m) => m.username.toLowerCase().contains(_filterQuery.toLowerCase())).toList();

    final roomDetailAsync = ref.watch(slskdRoomDetailProvider((widget.instance, widget.roomName)));
    final bool isPrivate = roomDetailAsync.value?.isPrivate ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Icon(Icons.people_alt_rounded, size: 22, color: colorScheme.primary),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  '${widget.roomName} Members (${members.length})',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPrivate)
                IconButton(
                  tooltip: 'Invite member to private room',
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  onPressed: _showInviteMemberDialog,
                ),
              IconButton(
                tooltip: 'Refresh member list',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () {
                  ref.invalidate(slskdRoomUsersProvider((widget.instance, widget.roomName)));
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),

          // Search member filter
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _filterQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search members...',
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _filterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filterQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
            ),
          ),
          const SizedBox(height: Insets.sm),

          // Member List
          Expanded(
            child: _buildMemberList(
              context,
              colorScheme: colorScheme,
              textTheme: textTheme,
              isLoading: !usersAsync.hasValue && !usersAsync.hasError && members.isEmpty,
              filtered: filtered,
              roomDetail: roomDetailAsync.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(
    BuildContext context, {
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isLoading,
    required List<SlskdUserPresence> filtered,
    required SlskdRoom? roomDetail,
  }) {
    if (isLoading) {
      return const Center(child: ExpressiveProgressIndicator());
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _filterQuery.isNotEmpty
              ? 'No members match "$_filterQuery"'
              : 'No members found',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        final member = filtered[index];
        final bool isOnline = member.isOnline;
        final bool isAway = member.isAway;
        final String memberLower = member.username.toLowerCase();
        final bool isOperator = roomDetail != null &&
            (roomDetail.operators.any((op) => op.toLowerCase() == memberLower) ||
                roomDetail.owner?.toLowerCase() == memberLower);

        final Color presenceColor = slskdPresenceColor(
          colorScheme,
          isOnline: isOnline,
          isAway: isAway,
        );

        final String speedStr =
            (member.averageSpeed.isFinite && member.averageSpeed > 0)
                ? slskdFormatRate(member.averageSpeed)
                : 'Direct';
        final String subtitle = member.fileCount > 0
            ? '${member.fileCount} shares • $speedStr'
            : (isOnline ? 'Online' : (isAway ? 'Away' : 'Offline'));

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: Insets.xs),
          leading: Stack(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: Text(
                  member.username.isNotEmpty
                      ? member.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: presenceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  member.username,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOperator) ...<Widget>[
                const SizedBox(width: Insets.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OP',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Row(
            children: <Widget>[
              Icon(
                slskdPresenceIcon(
                  isOnline: isOnline,
                  isAway: isAway,
                ),
                size: 11,
                color: presenceColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitle,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.more_vert_rounded, size: 18),
          onTap: () {
            final parentContext = Navigator.of(context).context;
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (parentContext.mounted) {
                showSlskdPeerActionSheet(
                  parentContext,
                  instance: widget.instance,
                  username: member.username,
                );
              }
            });
          },
        );
      },
    );
  }
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({required this.roomName});

  final String roomName;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite to #${widget.roomName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Soulseek Username',
          hintText: 'Enter username to grant access',
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
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: const Text('Invite'),
        ),
      ],
    );
  }
}
