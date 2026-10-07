import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adguard_home_access_edit.dart';
import 'adguard_home_errors.dart';
import 'adguard_home_providers.dart';
import 'adguard_home_query_log.dart';
import 'models/adguard_home_access.dart';

/// Shuts the client at [address] out of the server, or lets it back in when
/// it is [disallowed] now, after saying what that will do and asking.
///
/// Whether anything was changed is the result. A change is reported in a
/// message at the foot of the screen. Anything that stops short of one, a
/// refusal or a failure, is said in a dialog instead: this is asked from a
/// sheet, and a message under the sheet would not be seen.
Future<bool> adguardHomeToggleClientAccess(
  BuildContext context,
  WidgetRef ref,
  Instance instance, {
  required String address,
  required bool disallowed,
  required String disallowedRule,
}) async {
  // Taken before anything is awaited, as in a block.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AdguardHomeActions actions =
      ref.read(adguardHomeActionsProvider(instance));

  Future<void> explain(String title, String message) async {
    if (!context.mounted) {
      // The sheet this was asked from has been closed. Saying nothing would
      // leave the change believed to have been made.
      if (messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  try {
    final AdguardHomeAccessList list = await actions.readAccessList();
    if (adguardHomeIsLastAllowedClient(list, address, disallowed: disallowed)) {
      await explain(
        'This client stays allowed',
        AdguardHomeLastAllowedClient.message,
      );
      return false;
    }
    // Taking it off a list it is not on would write the lists back as they
    // are. The web UI does that and reports the client blocked.
    if (adguardHomeIsAllowedByWiderEntry(
      list,
      address,
      disallowed: disallowed,
    )) {
      await explain(
        'This client stays allowed',
        AdguardHomeAllowedByWiderEntry.message,
      );
      return false;
    }
    if (!context.mounted) return false;

    final String what;
    if (disallowed && list.allowlistInUse) {
      what = 'AdGuard Home will answer it again. This puts $address on the '
          'allowed clients.';
    } else if (disallowed) {
      final String rule = disallowedRule.isEmpty ? address : disallowedRule;
      what = 'AdGuard Home will answer it again. This removes $rule from '
          'the disallowed clients.';
    } else if (list.allowlistInUse) {
      what = 'AdGuard Home will drop every DNS query from $address. This '
          'takes $address off the allowed clients.';
    } else {
      what = 'AdGuard Home will drop every DNS query from $address. A device '
          'that has no other DNS server loses its internet access.';
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          disallowed ? 'Allow this client?' : 'Disallow this client?',
        ),
        content: Text(what),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(disallowed ? 'Allow' : 'Disallow'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    await actions.setClientAccess(
      address: address,
      disallowed: disallowed,
      disallowedRule: disallowedRule,
    );
    if (messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              disallowed
                  ? '$address is allowed again'
                  : '$address is now disallowed',
            ),
          ),
        );
    }
    return true;
  } on Object catch (error) {
    await explain('Nothing was changed', describeAdguardHomeError(error));
    return false;
  }
}

/// Throws the whole query log of [instance] away, after asking, and reads
/// the now empty log again.
Future<void> adguardHomeClearQueryLog(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AdguardHomeActions actions =
      ref.read(adguardHomeActionsProvider(instance));
  final AdguardHomeQueryLog log =
      ref.read(adguardHomeQueryLogProvider(instance).notifier);

  void say(String message) {
    if (!messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Clear the query log?'),
      content: const Text(
        'AdGuard Home deletes every entry of its query log. This cannot be '
        'undone.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await actions.clearQueryLog();
    say('Query log cleared');
    await log.reload();
  } on Object catch (error) {
    say(describeAdguardHomeError(error));
  }
}
