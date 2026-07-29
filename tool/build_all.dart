// This is a developer CLI helper (run via `dart run tool/build_all.dart`), so
// printing to the console is the intended output channel.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

class BuildResult {
  final String relativePath;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  BuildResult({
    required this.relativePath,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });
}

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  var concurrency = Platform.numberOfProcessors;
  final buildRunnerArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-j' || args[i] == '--concurrency') {
      if (i + 1 < args.length) {
        final parsed = int.tryParse(args[i + 1]);
        if (parsed != null) {
          concurrency = parsed;
          i++; // skip next arg
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

  // If no arguments are provided, default to build with delete-conflicting-outputs
  final commandArgs =
      buildRunnerArgs.isEmpty ? ['build', '--delete-conflicting-outputs'] : buildRunnerArgs;

  print(
    'Starting build_runner in workspace packages with concurrency $concurrency '
    'and arguments: ${commandArgs.join(' ')}\n',
  );

  final rootDir = Directory.current;
  final workspaceDirs = <Directory>[];

  // Recursively find all package directories containing a pubspec.yaml with
  // build_runner. A recursive list() has already descended by the time it hands
  // an entity back, so a directory cannot be pruned once it is seen; each
  // pubspec is judged by its own path instead. Filtering the directory entry
  // alone did nothing, because only files decide what gets added, which is how
  // a PUB_CACHE inside the tree came to offer every downloaded dependency up as
  // a package to build.
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

  final taskFactories = workspaceDirs.map((dir) {
    return () => runBuildRunner(dir, rootDir, commandArgs);
  }).toList();

  final results = await runWithConcurrencyLimit(concurrency, taskFactories);

  var successCount = 0;
  var failureCount = 0;

  for (final result in results) {
    if (result.exitCode == 0) {
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

  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'build_runner', ...commandArgs],
    workingDirectory: dir.path,
  );

  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();

  process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
  process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

  final exitCode = await process.exitCode;
  stopwatch.stop();

  final result = BuildResult(
    relativePath: relativePath,
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
    duration: stopwatch.elapsed,
  );

  print(
    '========================================================================',
  );
  print('Finished build_runner in: $relativePath (${result.duration.inSeconds}s)');
  print(
    '========================================================================',
  );
  if (result.stdout.isNotEmpty) {
    print(result.stdout);
  }
  if (result.stderr.isNotEmpty) {
    print(result.stderr);
  }
  if (result.exitCode == 0) {
    print('✔ Successfully completed in $relativePath\n');
  } else {
    print('✘ Failed with exit code ${result.exitCode} in $relativePath\n');
  }

  return result;
}

Future<List<BuildResult>> runWithConcurrencyLimit(
  int limit,
  List<Future<BuildResult> Function()> taskFactories,
) async {
  final results = List<BuildResult?>.filled(taskFactories.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex++;
      if (index >= taskFactories.length) {
        break;
      }
      results[index] = await taskFactories[index]();
    }
  }

  final workers = List.generate(
    limit < taskFactories.length ? limit : taskFactories.length,
    (_) => worker(),
  );

  await Future.wait(workers);
  return results.cast<BuildResult>();
}
