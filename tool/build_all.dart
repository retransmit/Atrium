// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const int maxDefaultConcurrency = 4;

class BuildResult {
  const BuildResult({
    required this.relativePath,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  final String relativePath;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  bool get succeeded => exitCode == 0;
}

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  final processors = Platform.numberOfProcessors;
  var concurrency =
      processors < maxDefaultConcurrency ? processors : maxDefaultConcurrency;
  final buildRunnerArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-j' || args[i] == '--concurrency') {
      if (i + 1 < args.length) {
        final parsed = int.tryParse(args[i + 1]);
        if (parsed != null) {
          concurrency = parsed;
          i++;
          continue;
        }
      }
    } else if (args[i].startsWith('--concurrency=')) {
      final parsed = int.tryParse(args[i].split('=')[1]);
      if (parsed != null) {
        concurrency = parsed;
        continue;
      }
    }
    buildRunnerArgs.add(args[i]);
  }

  if (concurrency < 1) {
    print('Concurrency must be at least 1, got $concurrency.');
    exit(64);
  }

  final commandArgs = buildRunnerArgs.isEmpty
      ? ['build', '--delete-conflicting-outputs']
      : buildRunnerArgs;

  print(
    'Starting build_runner in workspace packages with concurrency $concurrency '
    'and arguments: ${commandArgs.join(' ')}\n',
  );

  final rootDir = Directory.current;
  final workspaceDirs = <Directory>[];

  const skipSegments = {'build', 'ios', 'android'};
  await for (final entity
      in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('pubspec.yaml')) {
      continue;
    }
    final segments = entity.parent.path
        .replaceFirst(rootDir.path, '')
        .split(Platform.pathSeparator);
    if (segments.any((s) => s.startsWith('.') || skipSegments.contains(s))) {
      continue;
    }
    final content = await entity.readAsString();
    if (content.contains('build_runner:')) {
      workspaceDirs.add(entity.parent);
    }
  }

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

  final taskFactories = workspaceDirs
      .map((dir) => () => runBuildRunner(dir, rootDir, commandArgs))
      .toList();

  final results = await runWithConcurrencyLimit(concurrency, taskFactories);

  var successCount = 0;
  var failureCount = 0;

  for (final result in results) {
    if (result.succeeded) {
      successCount++;
    } else {
      failureCount++;
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

Future<BuildResult> runBuildRunner(
  Directory dir,
  Directory rootDir,
  List<String> commandArgs,
) async {
  final stopwatch = Stopwatch()..start();
  final relativePath =
      dir.path.replaceFirst(rootDir.path + Platform.pathSeparator, '');

  try {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'build_runner', ...commandArgs],
      workingDirectory: dir.path,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone =
        process.stdout.transform(utf8.decoder).forEach(stdoutBuffer.write);
    final stderrDone =
        process.stderr.transform(utf8.decoder).forEach(stderrBuffer.write);

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    stopwatch.stop();

    return BuildResult(
      relativePath: relativePath,
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      duration: stopwatch.elapsed,
    );
  } on Object catch (error) {
    stopwatch.stop();
    return BuildResult(
      relativePath: relativePath,
      exitCode: 1,
      stdout: '',
      stderr: 'Could not run build_runner: $error',
      duration: stopwatch.elapsed,
    );
  }
}

void reportResult(BuildResult result, int completed, int total) {
  print(
    '========================================================================',
  );
  print(
    '[$completed/$total] Finished build_runner in: ${result.relativePath} '
    '(${result.duration.inSeconds}s)',
  );
  print(
    '========================================================================',
  );
  if (result.stdout.isNotEmpty) {
    print(result.stdout);
  }
  if (result.stderr.isNotEmpty) {
    print(result.stderr);
  }
  if (result.succeeded) {
    print('✔ Successfully completed in ${result.relativePath}\n');
  } else {
    print(
      '✘ Failed with exit code ${result.exitCode} in ${result.relativePath}\n',
    );
  }
}

Future<List<BuildResult>> runWithConcurrencyLimit(
  int limit,
  List<Future<BuildResult> Function()> taskFactories,
) async {
  final results = List<BuildResult?>.filled(taskFactories.length, null);
  var nextIndex = 0;
  var completed = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex++;
      if (index >= taskFactories.length) {
        break;
      }
      final result = await taskFactories[index]();
      results[index] = result;
      completed++;
      reportResult(result, completed, taskFactories.length);
    }
  }

  final workers = List.generate(
    limit < taskFactories.length ? limit : taskFactories.length,
    (_) => worker(),
  );

  await Future.wait(workers);
  return results.cast<BuildResult>();
}
