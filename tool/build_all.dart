// This is a developer CLI helper (run via `dart run tool/build_all.dart`), so
// printing to the console is the intended output channel.
// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  // If no arguments are provided, default to build with delete-conflicting-outputs
  final commandArgs =
      args.isEmpty ? ['build', '--delete-conflicting-outputs'] : args;

  print(
    'Starting build_runner in workspace packages with arguments: '
    '${commandArgs.join(' ')}\n',
  );

  final rootDir = Directory.current;
  final workspaceDirs = <Directory>[];

  // Recursively find all package directories containing a pubspec.yaml with build_runner
  await for (final entity
      in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is Directory) {
      final name = entity.uri.pathSegments
          .lastWhere((s) => s.isNotEmpty, orElse: () => '');
      // Skip common hidden or build directories
      if (name.startsWith('.') ||
          name == 'build' ||
          name == 'ios' ||
          name == 'android') {
        continue;
      }
    } else if (entity is File && entity.path.endsWith('pubspec.yaml')) {
      final content = await entity.readAsString();
      if (content.contains('build_runner:')) {
        workspaceDirs.add(entity.parent);
      }
    }
  }

  // Sort them so they run in a predictable order
  workspaceDirs.sort((a, b) => a.path.compareTo(b.path));

  if (workspaceDirs.isEmpty) {
    print('No packages with build_runner dependency found.');
    return;
  }

  print('Found ${workspaceDirs.length} packages to run build_runner in:');
  for (final dir in workspaceDirs) {
    final relativePath =
        dir.path.replaceFirst(rootDir.path + Platform.pathSeparator, '');
    print('  - $relativePath');
  }
  print('');

  var successCount = 0;
  var failureCount = 0;

  for (final dir in workspaceDirs) {
    final relativePath =
        dir.path.replaceFirst(rootDir.path + Platform.pathSeparator, '');
    print(
      '========================================================================',
    );
    print('Running build_runner in: $relativePath');
    print(
      '========================================================================',
    );

    final process = await Process.start(
      'dart',
      ['run', 'build_runner', ...commandArgs],
      workingDirectory: dir.path,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      successCount++;
      print('✔ Successfully completed in $relativePath\n');
    } else {
      failureCount++;
      print('✘ Failed with exit code $exitCode in $relativePath\n');
    }
  }

  stopwatch.stop();
  final duration = stopwatch.elapsed;

  print(
    '========================================================================',
  );
  print('Summary:');
  print('  Total packages: ${workspaceDirs.length}');
  print('  Success: $successCount');
  print('  Failed: $failureCount');
  print('  Time elapsed: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
  print(
    '========================================================================',
  );

  if (failureCount > 0) {
    exit(1);
  }
}
