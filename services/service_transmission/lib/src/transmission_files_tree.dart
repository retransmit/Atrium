import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/transmission_detail.dart';
import 'transmission_api.dart';
import 'transmission_format.dart';
import 'transmission_visuals.dart';

/// A folder or file in a torrent, built from Transmission's flat file list.
///
/// Transmission reports files as `a/b/c.ext` paths with no folder objects, so
/// the tree is derived, and everything a folder says about itself (size,
/// progress, wanted) is summed from the files beneath it.
class TransmissionFileNode {
  TransmissionFileNode({
    required this.name,
    required this.path,
    this.fileIndex,
    this.file,
  });

  final String name;

  /// The full slash-separated path, which `torrent-rename-path` addresses.
  final String path;
  final List<TransmissionFileNode> children = <TransmissionFileNode>[];

  /// Index into the torrent's file list; null for a folder.
  final int? fileIndex;
  final TransmissionFile? file;

  bool get isFolder => fileIndex == null;

  int get length =>
      file?.length ??
      children.fold(0, (int s, TransmissionFileNode c) => s + c.length);

  int get bytesCompleted =>
      file?.bytesCompleted ??
      children.fold(0, (int s, TransmissionFileNode c) => s + c.bytesCompleted);

  double get progress =>
      length <= 0 ? 0 : (bytesCompleted / length).clamp(0, 1).toDouble();

  /// Every file index under this node, in file order.
  List<int> get indices => isFolder
      ? <int>[for (final TransmissionFileNode c in children) ...c.indices]
      : <int>[fileIndex!];

  bool get allWanted => isFolder
      ? children.every((TransmissionFileNode c) => c.allWanted)
      : file!.wanted;

  bool get anyWanted => isFolder
      ? children.any((TransmissionFileNode c) => c.anyWanted)
      : file!.wanted;
}

/// Builds the tree. The root has an empty name; its children are the top
/// level, which for a single-file torrent is that one file.
TransmissionFileNode buildTransmissionFileTree(List<TransmissionFile> files) {
  final TransmissionFileNode root = TransmissionFileNode(name: '', path: '');
  for (int i = 0; i < files.length; i++) {
    final TransmissionFile f = files[i];
    final List<String> parts = f.name.split('/');
    TransmissionFileNode node = root;
    for (int p = 0; p < parts.length; p++) {
      final String part = parts[p];
      final String path = parts.sublist(0, p + 1).join('/');
      if (p == parts.length - 1) {
        node.children.add(
          TransmissionFileNode(name: part, path: path, fileIndex: i, file: f),
        );
      } else {
        TransmissionFileNode? folder;
        for (final TransmissionFileNode c in node.children) {
          if (c.isFolder && c.name == part) {
            folder = c;
            break;
          }
        }
        if (folder == null) {
          folder = TransmissionFileNode(name: part, path: path);
          node.children.add(folder);
        }
        node = folder;
      }
    }
  }
  return root;
}

/// The Files tab's body: collapsible folders, a checkbox and a priority menu
/// on every row. Folder rows apply to every file beneath them in one call.
class TransmissionFilesTree extends StatefulWidget {
  const TransmissionFilesTree({
    required this.root,
    required this.busy,
    required this.onWanted,
    required this.onPriority,
    super.key,
  });

  final TransmissionFileNode root;

  /// Disables the controls while a write is in flight.
  final bool busy;
  final void Function(List<int> indices, bool wanted) onWanted;
  final void Function(List<int> indices, TransmissionPriority priority)
      onPriority;

  @override
  State<TransmissionFilesTree> createState() => _TransmissionFilesTreeState();
}

class _TransmissionFilesTreeState extends State<TransmissionFilesTree> {
  /// Paths of the folders folded shut. Top-level folders start open.
  final Set<String> _closed = <String>{};

  @override
  void initState() {
    super.initState();
    for (final TransmissionFileNode top in widget.root.children) {
      for (final TransmissionFileNode c in top.children) {
        if (c.isFolder) _closed.add(c.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    void walk(TransmissionFileNode node, int depth) {
      for (final TransmissionFileNode c in node.children) {
        rows.add(_row(c, depth));
        if (c.isFolder && !_closed.contains(c.path)) walk(c, depth + 1);
      }
    }

    walk(widget.root, 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.xl,
      ),
      children: <Widget>[
        TransmissionPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _row(TransmissionFileNode node, int depth) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool open = !_closed.contains(node.path);
    final bool? checked =
        node.allWanted ? true : (node.anyWanted ? null : false);
    return Padding(
      padding: EdgeInsets.only(left: depth * Insets.lg),
      child: Row(
        children: <Widget>[
          Checkbox(
            tristate: node.isFolder,
            value: checked,
            onChanged: widget.busy
                ? null
                : (bool? _) =>
                    widget.onWanted(node.indices, !(checked ?? false)),
          ),
          TransmissionIconBlock(
            icon: node.isFolder
                ? (open ? Icons.folder_open_rounded : Icons.folder_rounded)
                : Icons.insert_drive_file_outlined,
            background: node.isFolder
                ? cs.secondaryContainer
                : cs.surfaceContainerHighest,
            foreground:
                node.isFolder ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            size: 36,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: InkWell(
              onTap: node.isFolder
                  ? () => setState(() {
                        if (!_closed.remove(node.path)) _closed.add(node.path);
                      })
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      node.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicatorM3E(
                        value: node.progress,
                        shape: ProgressM3EShape.flat,
                        size: LinearProgressM3ESize.s,
                        trackColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${trPct(node.progress)}% - ${trFmtBytes(node.length)}'
                      '${node.isFolder ? '' : ' - ${node.file!.priorityLabel} priority'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<TransmissionPriority>(
            tooltip: 'Priority',
            icon: const Icon(Icons.low_priority),
            enabled: !widget.busy,
            onSelected: (TransmissionPriority p) =>
                widget.onPriority(node.indices, p),
            itemBuilder: (BuildContext _) =>
                const <PopupMenuEntry<TransmissionPriority>>[
              PopupMenuItem<TransmissionPriority>(
                value: TransmissionPriority.low,
                child: Text('Low'),
              ),
              PopupMenuItem<TransmissionPriority>(
                value: TransmissionPriority.normal,
                child: Text('Normal'),
              ),
              PopupMenuItem<TransmissionPriority>(
                value: TransmissionPriority.high,
                child: Text('High'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
