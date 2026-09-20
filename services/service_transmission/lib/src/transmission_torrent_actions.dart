import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_torrent.dart';
import 'transmission_api.dart';
import 'transmission_dialogs.dart';
import 'transmission_providers.dart';

/// Everything the web UI's context menu offers, worded as it words it.
enum TransmissionTorrentAction {
  resume('Resume', Icons.play_arrow),
  resumeNow('Resume now', Icons.flash_on),
  pause('Pause', Icons.pause),
  verify('Verify local data', Icons.fact_check_outlined),
  reannounce('Ask tracker for more peers', Icons.campaign_outlined),
  setLocation('Set location', Icons.drive_file_move_outline),
  rename('Rename', Icons.drive_file_rename_outline),
  editLabels('Edit labels', Icons.label_outline),
  copyMagnet('Copy magnet link', Icons.link),
  queueTop('Queue to top', Icons.vertical_align_top),
  queueUp('Queue up', Icons.arrow_upward),
  queueDown('Queue down', Icons.arrow_downward),
  queueBottom('Queue to bottom', Icons.vertical_align_bottom),
  remove('Remove from list', Icons.delete_outline),
  trash('Trash data and remove from list', Icons.delete_forever_outlined);

  const TransmissionTorrentAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The menu the row, the selection bar and the detail screen share.
///
/// [single] hides what the RPC only does for one torrent (rename, and the
/// magnet link, which is one torrent's); [labelsSupported] hides Edit labels
/// on a daemon below RPC 16.
List<PopupMenuEntry<TransmissionTorrentAction>> transmissionActionMenuItems({
  required bool anyStopped,
  required bool single,
  required bool labelsSupported,
}) {
  PopupMenuItem<TransmissionTorrentAction> item(TransmissionTorrentAction a) =>
      PopupMenuItem<TransmissionTorrentAction>(
        value: a,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(a.icon),
          title: Text(a.label),
        ),
      );
  return <PopupMenuEntry<TransmissionTorrentAction>>[
    item(TransmissionTorrentAction.resume),
    if (anyStopped) item(TransmissionTorrentAction.resumeNow),
    item(TransmissionTorrentAction.pause),
    item(TransmissionTorrentAction.verify),
    item(TransmissionTorrentAction.reannounce),
    const PopupMenuDivider(),
    item(TransmissionTorrentAction.setLocation),
    if (single) item(TransmissionTorrentAction.rename),
    if (labelsSupported) item(TransmissionTorrentAction.editLabels),
    if (single) item(TransmissionTorrentAction.copyMagnet),
    const PopupMenuDivider(),
    item(TransmissionTorrentAction.queueTop),
    item(TransmissionTorrentAction.queueUp),
    item(TransmissionTorrentAction.queueDown),
    item(TransmissionTorrentAction.queueBottom),
    const PopupMenuDivider(),
    item(TransmissionTorrentAction.remove),
    item(TransmissionTorrentAction.trash),
  ];
}

/// Runs one RPC action, reports a failure in a snackbar, and refreshes what
/// the screens watch either way. Returns whether it succeeded.
Future<bool> runTransmissionAction(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  Future<void> Function(TransmissionApi api) action, {
  String? done,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  bool ok = false;
  try {
    final TransmissionApi api =
        await ref.read(transmissionApiProvider(instance).future);
    await action(api);
    ok = true;
    if (done != null) {
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
  } finally {
    // The raw provider owns the fetch; invalidating only the derived filtered
    // one would re-filter stale data without going back to the server.
    ref
      ..invalidate(transmissionRawTorrentsProvider(instance))
      ..invalidate(transmissionSessionStatsProvider(instance));
  }
  return ok;
}

/// Carries out [action] on [targets], asking first where the web UI asks.
Future<void> performTransmissionAction(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  TransmissionTorrentAction action,
  List<TransmissionTorrent> targets,
) async {
  if (targets.isEmpty) return;
  final List<String> hashes = <String>[
    for (final TransmissionTorrent t in targets) t.hashString,
  ];
  final TransmissionTorrent first = targets.first;
  Future<void> run(Future<void> Function(TransmissionApi api) call) =>
      runTransmissionAction(context, ref, instance, call);
  switch (action) {
    case TransmissionTorrentAction.resume:
      await run((TransmissionApi api) => api.start(hashes));
    case TransmissionTorrentAction.resumeNow:
      await run((TransmissionApi api) => api.startNow(hashes));
    case TransmissionTorrentAction.pause:
      await run((TransmissionApi api) => api.stop(hashes));
    case TransmissionTorrentAction.verify:
      await run((TransmissionApi api) => api.verify(hashes));
    case TransmissionTorrentAction.reannounce:
      await run((TransmissionApi api) => api.reannounce(hashes));
    case TransmissionTorrentAction.queueTop:
      await run((TransmissionApi api) => api.queueTop(hashes));
    case TransmissionTorrentAction.queueUp:
      await run((TransmissionApi api) => api.queueUp(hashes));
    case TransmissionTorrentAction.queueDown:
      await run((TransmissionApi api) => api.queueDown(hashes));
    case TransmissionTorrentAction.queueBottom:
      await run((TransmissionApi api) => api.queueBottom(hashes));
    case TransmissionTorrentAction.setLocation:
      final String? path = await showTransmissionLocationDialog(
        context,
        initial: first.downloadDir,
      );
      if (path == null || path.isEmpty || !context.mounted) return;
      await run((TransmissionApi api) => api.setLocation(hashes, path));
    case TransmissionTorrentAction.rename:
      final String? name =
          await showTransmissionRenameDialog(context, initial: first.name);
      if (name == null ||
          name.isEmpty ||
          name == first.name ||
          !context.mounted) {
        return;
      }
      await run(
        (TransmissionApi api) => api.rename(
          first.hashString,
          oldName: first.name,
          newName: name,
        ),
      );
    case TransmissionTorrentAction.editLabels:
      final List<TransmissionTorrent> all =
          ref.read(transmissionRawTorrentsProvider(instance)).value ??
              const <TransmissionTorrent>[];
      // One torrent keeps its labels in the field; a mixed selection starts
      // blank rather than guessing whose labels to show.
      final List<String> initial =
          targets.length == 1 ? first.labels : const <String>[];
      final List<String>? labels = await showTransmissionLabelsDialog(
        context,
        initial: initial,
        suggestions: transmissionLabels(all),
      );
      if (labels == null || !context.mounted) return;
      await run((TransmissionApi api) => api.setLabels(hashes, labels));
    case TransmissionTorrentAction.copyMagnet:
      await runTransmissionAction(
        context,
        ref,
        instance,
        (TransmissionApi api) async {
          final String link = await api.getMagnetLink(first.hashString);
          await Clipboard.setData(ClipboardData(text: link));
        },
        done: 'Magnet link copied',
      );
    case TransmissionTorrentAction.remove:
    case TransmissionTorrentAction.trash:
      final bool? withData = await showTransmissionRemoveDialog(
        context,
        names: <String>[for (final TransmissionTorrent t in targets) t.name],
        trash: action == TransmissionTorrentAction.trash,
      );
      if (withData == null || !context.mounted) return;
      await run(
        (TransmissionApi api) =>
            api.remove(hashes, deleteLocalData: withData),
      );
  }
}
