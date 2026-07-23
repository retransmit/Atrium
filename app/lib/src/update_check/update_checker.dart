// app/lib/src/update_check/update_checker.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../external_links.dart';
import '../preferences.dart';
import 'app_version.dart';
import 'update_check_state.dart';
import 'version_compare.dart';

/// A plain Dio for the GitHub API, no per-instance auth. Overridden in tests.
final Provider<Dio> githubDioProvider = Provider<Dio>((Ref ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const <String, String>{'Accept': 'application/vnd.github+json'},
    ),
  );
});

final NotifierProvider<UpdateChecker, UpdateCheckState> updateCheckProvider =
    NotifierProvider<UpdateChecker, UpdateCheckState>(UpdateChecker.new);

/// Checks GitHub for a newer release, only when [check] is called. Never
/// fetches on construction; [build] only reads the persisted last result.
class UpdateChecker extends Notifier<UpdateCheckState> {
  static const String _latestKey = 'update.latestVersion';
  static const String _urlKey = 'update.releaseUrl';
  static const String _checkedAtKey = 'update.checkedAt';

  Box<String> get _box => ref.read(settingsBoxProvider);

  @override
  UpdateCheckState build() {
    final String? latest = _box.get(_latestKey);
    final String? url = _box.get(_urlKey);
    final String? checkedAtRaw = _box.get(_checkedAtKey);
    final DateTime? checkedAt =
        checkedAtRaw == null ? null : DateTime.tryParse(checkedAtRaw);

    final UpdateStatus status;
    if (latest == null) {
      status = UpdateStatus.idle;
    } else if (compareVersions(latest, appVersion) > 0) {
      status = UpdateStatus.updateAvailable;
    } else {
      status = UpdateStatus.upToDate;
    }
    return UpdateCheckState(
      status: status,
      latestVersion: latest,
      releaseUrl: url,
      checkedAt: checkedAt,
    );
  }

  /// Fetches the latest release and updates state. Errors keep the durable
  /// fields so a known "available" banner survives a failed check.
  Future<void> check() async {
    state = state.copyWith(status: UpdateStatus.checking);
    try {
      final Dio dio = ref.read(githubDioProvider);
      final Response<Map<String, dynamic>> res =
          await dio.get<Map<String, dynamic>>(
        'repos/retransmit/Atrium/releases/latest',
      );
      final Map<String, dynamic> data = res.data ?? <String, dynamic>{};
      final String? tag = data['tag_name'] as String?;
      if (tag == null || tag.isEmpty) {
        state = state.copyWith(status: UpdateStatus.error);
        return;
      }
      final String latest = tag.startsWith('v') ? tag.substring(1) : tag;
      final String url = (data['html_url'] as String?) ?? AtriumLinks.releases;
      final DateTime now = DateTime.now();
      await _box.put(_latestKey, latest);
      await _box.put(_urlKey, url);
      await _box.put(_checkedAtKey, now.toIso8601String());
      state = UpdateCheckState(
        status: compareVersions(latest, appVersion) > 0
            ? UpdateStatus.updateAvailable
            : UpdateStatus.upToDate,
        latestVersion: latest,
        releaseUrl: url,
        checkedAt: now,
      );
    } catch (_) {
      state = state.copyWith(status: UpdateStatus.error);
    }
  }
}
