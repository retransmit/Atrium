import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:service_lidarr/service_lidarr.dart';
import 'package:service_lidarr/src/features/system/views/log_file_reader_screen.dart';
import 'package:service_lidarr/src/features/system/views/log_files_view.dart';

import 'test_helpers.dart';

/// Stands in for the system save sheet and keeps what it was handed.
class _SaveSheet extends FilePickerPlatform with MockPlatformInterfaceMixin {
  String? fileName;
  Uint8List? bytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    required String fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    required Uint8List bytes,
    dynamic Function(FilePickerStatus)? onFileLoading,
    bool lockParentWindow = false,
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    return '/storage/emulated/0/Download/$fileName';
  }
}

const LogFileResource _file = LogFileResource(
  id: 1,
  filename: 'lidarr.txt',
  lastWriteTime: '2026-11-24T10:00:00Z',
  contentsUrl: '/api/v1/log/file/lidarr.txt',
  downloadUrl: '/logfile/lidarr.txt',
);

const String _log = '2026-11-24 10:00:00.0|Info|Bootstrap|Starting Lidarr\n';

/// Saving a log file hands the system save sheet the text the app read
/// through its API. It used to open the browser on a URL with the api key in
/// its query, which put the key in the browser's history and in any reverse
/// proxy's access log.
void main() {
  late _SaveSheet sheet;

  setUp(() {
    sheet = _SaveSheet();
    FilePickerPlatform.instance = sheet;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lidarrLogFilesProvider(testInstance)
              .overrideWith((Ref ref) async => <LogFileResource>[_file]),
          // Slow, as a real read over the network is, so a provider dropped
          // while it is still loading shows up as a log that never saves.
          lidarrLogFileContentProvider.overrideWith((ref, key) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return _log;
          }),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectSaved(WidgetTester tester) {
    expect(sheet.fileName, 'lidarr.txt');
    expect(utf8.decode(sheet.bytes!), _log);
    expect(find.textContaining('test-api-key'), findsNothing);
  }

  testWidgets('the reader saves the log it is showing', (tester) async {
    await pump(
      tester,
      const LogFileReaderScreen(instance: testInstance, file: _file),
    );
    await tester.tap(find.byTooltip('Download log file'));
    await tester.pumpAndSettle();
    expectSaved(tester);
  });

  testWidgets('the list saves a log without opening it', (tester) async {
    await pump(tester, const LogFilesView(instance: testInstance));
    await tester.tap(find.byTooltip('Download'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expectSaved(tester);
  });

  testWidgets('the details dialog saves it too', (tester) async {
    await pump(tester, const LogFilesView(instance: testInstance));
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Download'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expectSaved(tester);
  });
}
