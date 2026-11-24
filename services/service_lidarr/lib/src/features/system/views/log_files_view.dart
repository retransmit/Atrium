import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lidarr_formatters.dart';
import '../../../generated/generated.dart';
import '../../../lidarr_providers.dart';
import '../log_file_save.dart';
import 'log_file_reader_screen.dart';

/// Log files available on disk view.
class LogFilesView extends ConsumerWidget {
  const LogFilesView({required this.instance, super.key});

  final Instance instance;

  Future<void> _downloadFile(
    BuildContext context,
    WidgetRef ref,
    LogFileResource file,
  ) {
    final provider = lidarrLogFileContentProvider(
      (
        instance,
        filename: file.filename ?? '',
        contentsUrl: file.contentsUrl,
        downloadUrl: file.downloadUrl,
      ),
    );
    return saveLidarrLogFile(
      context,
      filename: file.filename ?? 'lidarr.txt',
      read: () => ref.read(provider.future),
    );
  }

  void _openFileReader(BuildContext context, LogFileResource file) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LogFileReaderScreen(
          instance: instance,
          file: file,
        ),
      ),
    );
  }

  void _showFileDetailDialog(
    BuildContext context,
    WidgetRef ref,
    LogFileResource file,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.filename ?? 'Log File',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Last Modified'),
                subtitle: Text(LidarrFormatters.formatDate(file.lastWriteTime)),
                dense: true,
              ),
              if (file.contentsUrl != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: const Text('Contents URL'),
                  subtitle: Text(file.contentsUrl!),
                  dense: true,
                ),
              if (file.downloadUrl != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download),
                  title: const Text('Download URL'),
                  subtitle: Text(file.downloadUrl!),
                  dense: true,
                ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Name'),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: file.filename ?? 'Log File'),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "${file.filename}" to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadFile(context, ref, file);
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Read Log'),
              onPressed: () {
                Navigator.pop(ctx);
                _openFileReader(context, file);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final asyncFiles = ref.watch(lidarrLogFilesProvider(instance));

    return EasyRefresh(
      onRefresh: () async {
        ref.invalidate(lidarrLogFilesProvider(instance));
      },
      child: AsyncValueView<List<LogFileResource>>(
        value: asyncFiles,
        data: (files) {
          if (files.isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.folder_open_outlined,
                title: 'No Log Files',
                message: 'No log files available on disk.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final LogFileResource file = files[index];

              return Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openFileReader(context, file),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.filename ?? 'Log File',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Modified ${LidarrFormatters.formatDate(file.lastWriteTime)}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_outlined, size: 20),
                          tooltip: 'Download',
                          onPressed: () => _downloadFile(context, ref, file),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: 'Details',
                          onPressed: () => _showFileDetailDialog(context, ref, file),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
