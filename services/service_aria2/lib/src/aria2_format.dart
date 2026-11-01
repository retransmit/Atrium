/// Formatting helpers shared by the aria2 screens.
///
/// Kept apart from the widgets so the labels can be unit-tested without a
/// Flutter binding.
library;

/// A byte count as a human string: '0 B', '512 B', '1.5 KB', '3.2 GB'.
String aria2FmtBytes(num bytes) {
  if (bytes < 1024) {
    return '${bytes.round()} B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB', 'PB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// A byte rate as a human string: '1.5 MB/s'.
String aria2FmtRate(int bytesPerSec) => '${aria2FmtBytes(bytesPerSec)}/s';

/// A duration as a short, human string: '45s', '3m 20s', '2h 5m'.
String aria2FormatEta(int seconds) {
  if (seconds <= 0) {
    return '0s';
  }
  if (seconds < 60) {
    return '${seconds}s';
  }
  if (seconds < 3600) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
  }
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

/// A human label for aria2's own status strings.
String aria2StatusLabel(String status, {bool seeder = false}) {
  if (status == 'active' && seeder) {
    return 'Seeding';
  }
  return switch (status) {
    'active' => 'Downloading',
    'waiting' => 'Queued',
    'paused' => 'Paused',
    'complete' => 'Complete',
    'error' => 'Error',
    'removed' => 'Removed',
    '' => 'Unknown',
    _ => status,
  };
}
