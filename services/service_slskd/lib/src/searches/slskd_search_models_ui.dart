import '../models/slskd_models.dart';
import '../slskd_format.dart';

/// Available sorting criteria for search results.
enum SlskdSearchSort {
  fastestSpeed,
  highestQuality,
  shortestQueue,
  fileCount;

  String get label => switch (this) {
        SlskdSearchSort.fastestSpeed => 'Fastest Speed',
        SlskdSearchSort.highestQuality => 'Highest Quality (FLAC/Bitrate)',
        SlskdSearchSort.shortestQueue => 'Shortest Queue',
        SlskdSearchSort.fileCount => 'Most Tracks (Full Albums)',
      };
}

/// Available audio format filters for search results.
enum SlskdSearchFormatFilter {
  all,
  flacOnly,
  mp3Only,
  oggOnly,
  wavOnly,
  aacOnly,
  m4aOnly,
  opusOnly;

  String get label => switch (this) {
        SlskdSearchFormatFilter.all => 'All Formats',
        SlskdSearchFormatFilter.flacOnly => 'FLAC Only',
        SlskdSearchFormatFilter.mp3Only => 'MP3 Only',
        SlskdSearchFormatFilter.oggOnly => 'OGG Only',
        SlskdSearchFormatFilter.wavOnly => 'WAV Only',
        SlskdSearchFormatFilter.aacOnly => 'AAC Only',
        SlskdSearchFormatFilter.m4aOnly => 'M4A Only',
        SlskdSearchFormatFilter.opusOnly => 'Opus Only',
      };

  bool matchesExtension(String ext) {
    final String clean = ext.trim().replaceAll(RegExp(r'^\.+'), '');
    final String upper = clean.toUpperCase();
    return switch (this) {
      SlskdSearchFormatFilter.all => true,
      SlskdSearchFormatFilter.flacOnly => upper == 'FLAC',
      SlskdSearchFormatFilter.mp3Only => upper == 'MP3',
      SlskdSearchFormatFilter.oggOnly => upper == 'OGG',
      SlskdSearchFormatFilter.wavOnly => upper == 'WAV',
      SlskdSearchFormatFilter.aacOnly => upper == 'AAC',
      SlskdSearchFormatFilter.m4aOnly => upper == 'M4A',
      SlskdSearchFormatFilter.opusOnly => upper == 'OPUS',
    };
  }
}

/// Grouped search results representing an entire album directory from a single peer.
class SlskdAlbumGroup {
  const SlskdAlbumGroup({
    required this.albumDirectory,
    required this.username,
    required this.hasFreeUploadSlot,
    required this.queueLength,
    required this.uploadSpeed,
    required this.files,
  });

  final String albumDirectory;
  final String username;
  final bool hasFreeUploadSlot;
  final int queueLength;
  final int uploadSpeed;
  final List<SlskdSearchFile> files;

  /// Extract friendly album name from full directory path.
  String get albumTitle {
    if (albumDirectory.isEmpty) return 'Loose Tracks';
    final parts = albumDirectory
        .replaceAll('\\', '/')
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.last : albumDirectory;
  }

  /// Full total byte size of all tracks in this album directory.
  int get totalSize => files.fold<int>(0, (sum, f) => sum + f.size);

  /// Human formatted size (e.g. '420 MB').
  String get formattedTotalSize => slskdFormatBytes(totalSize);

  /// Formatted upload speed (e.g. '2.5 MB/s').
  String get formattedSpeed => uploadSpeed > 0 ? slskdFormatRate(uploadSpeed) : 'Unknown';

  /// Predominant quality in this folder.
  String get qualityBadge {
    final flacFiles = files.where((f) => f.extension.toUpperCase().replaceAll(RegExp(r'^\.+'), '') == 'FLAC');
    if (flacFiles.isNotEmpty) {
      final highRes = flacFiles.firstWhere(
        (f) => (f.bitDepth ?? 0) > 16,
        orElse: () => flacFiles.first,
      );
      if ((highRes.bitDepth ?? 0) > 16) {
        return 'FLAC ${highRes.bitDepth}-bit';
      }
      return 'FLAC';
    }
    final maxBitrate = files.fold<int>(0, (max, f) => (f.bitRate ?? 0) > max ? f.bitRate! : max);
    if (maxBitrate > 0) {
      final topFile = files.firstWhere(
        (f) => (f.bitRate ?? 0) == maxBitrate,
        orElse: () => files.first,
      );
      final ext = topFile.extension.isNotEmpty ? topFile.extension.toUpperCase() : 'MP3';
      return '$ext ${maxBitrate}k';
    }
    return files.isNotEmpty ? files.first.extension.toUpperCase() : 'AUDIO';
  }
}
