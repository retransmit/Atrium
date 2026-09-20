import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'services/ombi_client.dart';

Future<void> approveOmbiRequest(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  OmbiRequest request,
) =>
    _run(
      context,
      ref,
      instance,
      'Approved',
      (OmbiClient c) => c.requestService.approve(request.kind, request.id),
    );

/// Asks for an optional reason first; cancelling the dialog does nothing.
Future<void> denyOmbiRequest(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  OmbiRequest request,
) async {
  final String? reason = await showDialog<String>(
    context: context,
    builder: (BuildContext _) => _DenyDialog(title: request.title),
  );
  if (reason == null || !context.mounted) {
    return;
  }
  await _run(
    context,
    ref,
    instance,
    'Denied',
    (OmbiClient c) =>
        c.requestService.deny(request.kind, request.id, reason: reason),
  );
}

/// Asks for confirmation first; the request only leaves Ombi's list.
Future<void> deleteOmbiRequest(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  OmbiRequest request,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Delete this request?'),
      content: Text(
        "${request.title} leaves Ombi's request list. Anything already "
        'downloaded stays where it is.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  await _run(
    context,
    ref,
    instance,
    'Deleted',
    (OmbiClient c) => c.requestService.delete(request.kind, request.id),
  );
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  String done,
  Future<void> Function(OmbiClient client) action,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await runOmbiAction(ref, instance, action);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(describeOmbiFailure(error))),
    );
  }
}

class _DenyDialog extends StatefulWidget {
  const _DenyDialog({required this.title});

  final String title;

  @override
  State<_DenyDialog> createState() => _DenyDialogState();
}

class _DenyDialogState extends State<_DenyDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Deny ${widget.title}?'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Deny'),
        ),
      ],
    );
  }
}
