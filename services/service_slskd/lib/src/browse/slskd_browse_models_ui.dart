import '../models/slskd_models.dart';
import '../slskd_format.dart';

/// In-memory tree node representing a directory in a peer's file shares.
class BrowseNode {
  BrowseNode({
    required this.segment,
    required this.fullPath,
    this.isLocked = false,
    Map<String, BrowseNode>? subfolders,
    List<SlskdSearchFile>? files,
  })  : subfolders = subfolders ?? <String, BrowseNode>{},
        files = files ?? <SlskdSearchFile>[];

  final String segment;
  final String fullPath;
  bool isLocked;
  final Map<String, BrowseNode> subfolders;
  final List<SlskdSearchFile> files;

  int get totalFiles =>
      files.length + subfolders.values.fold<int>(0, (sum, child) => sum + child.totalFiles);

  int get totalBytes =>
      files.fold<int>(0, (sum, f) => sum + f.size) +
      subfolders.values.fold<int>(0, (sum, child) => sum + child.totalBytes);

  String get formattedTotalSize => slskdFormatBytes(totalBytes);

  /// Collects all files in this node and all descendant subfolders.
  List<SlskdSearchFile> getAllFilesRecursive() {
    final List<SlskdSearchFile> list = <SlskdSearchFile>[...files];
    for (final child in subfolders.values) {
      list.addAll(child.getAllFilesRecursive());
    }
    return list;
  }

  /// The files a folder download can request: locked folders and locked
  /// files are left out, since the peer refuses them.
  List<SlskdSearchFile> getDownloadableFilesRecursive() {
    if (isLocked) return const <SlskdSearchFile>[];
    final List<SlskdSearchFile> list =
        files.where((SlskdSearchFile f) => !f.isLocked).toList();
    for (final child in subfolders.values) {
      list.addAll(child.getDownloadableFilesRecursive());
    }
    return list;
  }

  void _lockDescendants() {
    for (final child in subfolders.values) {
      if (isLocked) child.isLocked = true;
      child._lockDescendants();
    }
  }

  /// Builds a complete hierarchical tree from slskd's flat list of [SlskdDirectory].
  static BrowseNode buildTree(List<SlskdDirectory> directories) {
    final root = BrowseNode(segment: 'Root', fullPath: '');

    for (final dir in directories) {
      final parts =
          dir.name.split(RegExp(r'[\\/]')).where((p) => p.trim().isNotEmpty).toList();

      BrowseNode current = root;
      String currentPath = '';

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final bool parentLocked = current.isLocked;
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
        current = current.subfolders.putIfAbsent(
          part,
          () => BrowseNode(segment: part, fullPath: currentPath, isLocked: parentLocked),
        );
        if (parentLocked) {
          current.isLocked = true;
        }
      }

      // Add files to the leaf directory node
      if (dir.isLocked) {
        current.isLocked = true;
      }
      current.files.addAll(dir.files);
      // Sort files naturally by filename
      current.files.sort((a, b) => a.filename.compareTo(b.filename));
    }

    // A locked folder can arrive after its subfolders, so pass the lock down
    // once the whole tree exists.
    root._lockDescendants();
    return root;
  }
}
