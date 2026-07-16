import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seerr_api.dart';
import 'seerr_issue_detail_screen.dart';
import 'seerr_providers.dart';

/// Opens the report-issue sheet over the root navigator (required so the
/// sheet covers Atrium's bottom-nav shell).
Future<void> showSeerrReportIssueSheet(
  BuildContext context, {
  required Instance instance,
  required int mediaId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SeerrReportIssueSheet(
      instance: instance,
      mediaId: mediaId,
      title: title,
    ),
  );
}

/// Bottom sheet to report a media issue: an issue-type selector (Video /
/// Audio / Subtitles / Other), a message field, and Submit -> `createIssue`.
/// On success it snackbars, pops, and invalidates the issues list.
class SeerrReportIssueSheet extends ConsumerStatefulWidget {
  const SeerrReportIssueSheet({
    required this.instance,
    required this.mediaId,
    required this.title,
    super.key,
  });

  final Instance instance;

  /// Seerr's internal media DB id (`SeerrMedia.id`), not the TMDB id.
  final int mediaId;

  /// Display title of the media being reported, for the sheet header.
  final String title;

  @override
  ConsumerState<SeerrReportIssueSheet> createState() =>
      _SeerrReportIssueSheetState();
}

class _SeerrReportIssueSheetState extends ConsumerState<SeerrReportIssueSheet> {
  static const List<(int, String)> _types = <(int, String)>[
    (1, 'Video'),
    (2, 'Audio'),
    (3, 'Subtitles'),
    (4, 'Other'),
  ];

  final TextEditingController _messageController = TextEditingController();
  int _issueType = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final SeerrApi api =
          await ref.read(seerrApiProvider(widget.instance).future);
      await api.createIssue(
        issueType: _issueType,
        message: message,
        mediaId: widget.mediaId,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(seerrIssuesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Issue reported')));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Could not report issue: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSubmit =
        !_submitting && _messageController.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Report an issue',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 2),
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final (int type, String label) in _types)
                  ChoiceChip(
                    avatar: _issueType == type
                        ? null
                        : Icon(seerrIssueTypeIcon(type), size: 18),
                    label: Text(label),
                    selected: _issueType == type,
                    onSelected: (_) => setState(() => _issueType = type),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What is wrong?',
                hintText: 'Describe the problem',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ExpressiveProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
