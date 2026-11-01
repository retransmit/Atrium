import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/slskd_models.dart';
import 'slskd_api.dart';

/// Configured polling interval for a given [Instance], respecting [Instance.pollingIntervalSeconds].
Duration slskdPollInterval(Instance instance) =>
    Duration(seconds: instance.pollingIntervalSeconds.clamp(1, 60).toInt());

// -----------------------------------------------------------------------------
// UI Navigation & Tab State Providers
// -----------------------------------------------------------------------------

/// Active tab index for [SlskdHome] (0 to 4):
/// 0: Transfers, 1: Search, 2: Browse, 3: Community, 4: System
final slskdActiveTabProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 0);

/// Bottom navigation bar visibility (auto-hides on downward scroll).
final slskdBottomNavVisibleProvider =
    StateProvider.autoDispose.family<bool, Instance>((ref, instance) => true);

/// Triggers scroll-to-top when re-tapping the currently active navigation item.
final slskdScrollToTopProvider =
    StateProvider.autoDispose.family<int, (Instance, int)>(
  (ref, arg) => 0,
);

/// Selected search identifier for viewing search results.
final slskdSelectedSearchIdProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

/// Selected remote username in the Browse tab.
final slskdBrowseUsernameProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

/// Active folder breadcrumb path segments in the Browse tab.
final slskdBrowsePathSegmentsProvider =
    StateProvider.autoDispose.family<List<String>, Instance>(
  (ref, instance) => const <String>[],
);

/// Currently open chat room name in the Community tab.
final slskdActiveRoomNameProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

/// Currently open direct message conversation peer username.
final slskdActiveConversationUsernameProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

/// Active segmented view in Community tab (0: Rooms, 1: Direct Messages).
final slskdCommunitySegmentProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 0);

/// Active segmented view in System tab (0: Health, 1: Shares, 2: Logs).
final slskdSystemSegmentProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 0);

/// Log level filter ('All', 'Error', 'Warning', 'Information', 'Debug').
final slskdLogSeverityFilterProvider =
    StateProvider.autoDispose.family<String, Instance>((ref, instance) => 'All');

/// Search filter query for System logs.
final slskdLogSearchQueryProvider =
    StateProvider.autoDispose.family<String, Instance>((ref, instance) => '');

/// Timeframe in days for transfer reports (e.g. 1, 7, 30 days).
final slskdAnalyticsTimeframeDaysProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 7);

/// Selected historical log file name (null = live stream).
final slskdSelectedHistoricalLogProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

// -----------------------------------------------------------------------------
// API Client Provider
// -----------------------------------------------------------------------------

/// Dio HTTP API client instance for [SlskdApi].
final slskdApiProvider =
    FutureProvider.family<SlskdApi, Instance>((ref, instance) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return SlskdApi(dio);
}, retry: (_, _) => null);

// -----------------------------------------------------------------------------
// System & State Providers
// -----------------------------------------------------------------------------

/// Overall application state from GET /api/v0/application, polled while active.
final slskdApplicationStateProvider =
    FutureProvider.autoDispose.family<SlskdApplicationState, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getApplicationState();
}), retry: (_, _) => null);

/// Local file shares mapped by host from GET /api/v0/shares.
final slskdSharesProvider =
    FutureProvider.autoDispose.family<Map<String, List<SlskdLocalShare>>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getShares();
}, retry: (_, _) => null);

/// All shared contents across shares from GET /api/v0/shares/contents.
final slskdAllSharedContentsProvider =
    FutureProvider.autoDispose.family<List<SlskdDirectory>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getAllSharedContents();
}, retry: (_, _) => null);

/// Shared contents of a specific share from GET /api/v0/shares/{id}/contents.
final slskdShareContentsProvider =
    FutureProvider.autoDispose.family<List<SlskdDirectory>, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getShareContents(arg.$2);
}, retry: (_, _) => null);

/// Downloads directory contents from GET /api/v0/files/downloads/directories[/{subdirectory}].
final slskdDownloadsDirectoryProvider =
    FutureProvider.autoDispose.family<SlskdDiskDirectory?, (Instance, String?)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getDownloadsDirectory(subdirectory: arg.$2);
}, retry: (_, _) => null);

/// Incomplete directory contents from GET /api/v0/files/incomplete/directories[/{subdirectory}].
final slskdIncompleteDirectoryProvider =
    FutureProvider.autoDispose.family<SlskdDiskDirectory?, (Instance, String?)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getIncompleteDirectory(subdirectory: arg.$2);
}, retry: (_, _) => null);

/// Historical log files on disk from GET /api/v0/logs/files.
final slskdLogFilesProvider =
    FutureProvider.autoDispose.family<List<SlskdDiskFile>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getLogFiles();
}, retry: (_, _) => null);

/// Historical log file content from GET /api/v0/logs/files/{filename}.
final slskdLogFileContentProvider =
    FutureProvider.autoDispose.family<String, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getLogFileContent(arg.$2);
}, retry: (_, _) => null);

/// Application options from GET /api/v0/options.
final slskdOptionsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getOptions();
}, retry: (_, _) => null);

/// Debug transfer state from GET /api/v0/debug/transfers.
final slskdDebugTransfersProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getDebugTransfers();
}, retry: (_, _) => null);

/// Application logs from GET /api/v0/logs, polled while active.
final slskdLogsProvider =
    FutureProvider.autoDispose.family<List<SlskdLogRecord>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getLogs();
}), retry: (_, _) => null);

/// Filtered application logs matching severity and search query.
final slskdFilteredLogsProvider =
    FutureProvider.autoDispose.family<List<SlskdLogRecord>, Instance>((
  ref,
  instance,
) async {
  final String severity = ref.watch(slskdLogSeverityFilterProvider(instance));
  final String query =
      ref.watch(slskdLogSearchQueryProvider(instance)).trim().toLowerCase();
  final List<SlskdLogRecord> logs =
      await ref.watch(slskdLogsProvider(instance).future);

  return logs.where((SlskdLogRecord log) {
    if (severity != 'All' && log.level.toLowerCase() != severity.toLowerCase()) {
      return false;
    }
    if (query.isNotEmpty) {
      final bool inMsg = log.message.toLowerCase().contains(query);
      final bool inCtx = log.context?.toLowerCase().contains(query) ?? false;
      final bool inSub = log.subContext?.toLowerCase().contains(query) ?? false;
      return inMsg || inCtx || inSub;
    }
    return true;
  }).toList();
}, retry: (_, _) => null);

// -----------------------------------------------------------------------------
// Transfers Providers
// -----------------------------------------------------------------------------

/// Active downloads grouped by user and directory from GET /api/v0/transfers/downloads, polled while watched.
final slskdDownloadsProvider =
    FutureProvider.autoDispose.family<List<SlskdUserTransfers>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getDownloads();
}), retry: (_, _) => null);

/// Active uploads grouped by user and directory from GET /api/v0/transfers/uploads, polled while watched.
final slskdUploadsProvider =
    FutureProvider.autoDispose.family<List<SlskdUserTransfers>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getUploads();
}), retry: (_, _) => null);

// -----------------------------------------------------------------------------
// Telemetry & Historical Analytics Providers
// -----------------------------------------------------------------------------

/// Transfer leaderboard from GET /api/v0/telemetry/reports/transfers/leaderboard.
final slskdTransferLeaderboardProvider =
    FutureProvider.autoDispose.family<List<SlskdTransferSummary>, (Instance, String)>((
  ref,
  arg,
) async {
  final int days = ref.watch(slskdAnalyticsTimeframeDaysProvider(arg.$1));
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  final DateTime start = DateTime.now().subtract(Duration(days: days));
  return api.getTransferLeaderboard(direction: arg.$2, start: start, limit: 15);
}, retry: (_, _) => null);

/// Pareto failure reasons for direction ('Download' or 'Upload').
final slskdTransferExceptionsParetoProvider =
    FutureProvider.autoDispose.family<List<SlskdTransferExceptionSummary>, (Instance, String)>((
  ref,
  arg,
) async {
  final int days = ref.watch(slskdAnalyticsTimeframeDaysProvider(arg.$1));
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  final DateTime start = DateTime.now().subtract(Duration(days: days));
  return api.getTransferExceptionsPareto(direction: arg.$2, start: start, limit: 10);
}, retry: (_, _) => null);

/// Frequently downloaded directories from GET /api/v0/telemetry/reports/transfers/directories.
final slskdTransferDirectoriesProvider =
    FutureProvider.autoDispose.family<List<SlskdTransferDirectorySummary>, Instance>((
  ref,
  instance,
) async {
  final int days = ref.watch(slskdAnalyticsTimeframeDaysProvider(instance));
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  final DateTime start = DateTime.now().subtract(Duration(days: days));
  return api.getTransferDirectories(start: start, limit: 10);
}, retry: (_, _) => null);

/// Prometheus KPIs from GET /api/v0/telemetry/metrics/kpis.
final slskdPrometheusKpisProvider =
    FutureProvider.autoDispose.family<Map<String, SlskdPrometheusMetric>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getPrometheusKpis();
}, retry: (_, _) => null);

// -----------------------------------------------------------------------------
// Search Providers
// -----------------------------------------------------------------------------

/// Active and past searches from GET /api/v0/searches, polled while watched.
final slskdSearchesProvider =
    FutureProvider.autoDispose.family<List<SlskdSearch>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getSearches();
}), retry: (_, _) => null);

/// File responses for a given search id from GET /api/v0/searches/{id}/responses.
final slskdSearchResponsesProvider =
    FutureProvider.autoDispose.family<List<SlskdSearchResponse>, (Instance, String)>((
  ref,
  arg,
) => ref.polled(slskdPollInterval(arg.$1), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getSearchResponses(arg.$2);
}), retry: (_, _) => null);

// -----------------------------------------------------------------------------
// Browse & User Providers
// -----------------------------------------------------------------------------

/// Remote peer directory listing from GET /api/v0/users/{username}/browse.
final slskdUserDirectoriesProvider =
    FutureProvider.autoDispose.family<List<SlskdDirectory>, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.browseUser(arg.$2);
}, retry: (_, _) => null);

/// User bio and avatar profile info from GET /api/v0/users/{username}/info.
final slskdUserInfoProvider =
    FutureProvider.autoDispose.family<SlskdUserInfo, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getUserInfo(arg.$2);
}, retry: (_, _) => null);

/// User presence status from GET /api/v0/users/{username}/status.
final slskdUserStatusProvider =
    FutureProvider.autoDispose.family<SlskdUserStatus, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getUserStatus(arg.$2);
}, retry: (_, _) => null);

/// Active browse progress status (percent complete) from GET /api/v0/users/{username}/browse/status.
final slskdBrowseStatusProvider =
    FutureProvider.autoDispose.family<double?, (Instance, String)>((
  ref,
  arg,
) => ref.polled(slskdPollInterval(arg.$1), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getBrowseStatus(arg.$2);
}), retry: (_, _) => null);

/// Live queue position for a queued download from GET /api/v0/transfers/downloads/{username}/{id}/position.
final slskdQueuePositionProvider =
    FutureProvider.autoDispose.family<int?, (Instance, String, String)>((
  ref,
  arg,
) => ref.polled(slskdPollInterval(arg.$1), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getPlaceInQueue(arg.$2, arg.$3);
}), retry: (_, _) => null);

/// Remote peer endpoint (IP & port) from GET /api/v0/users/{username}/endpoint.
final slskdUserEndpointProvider =
    FutureProvider.autoDispose.family<SlskdUserEndpoint?, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getUserEndpoint(arg.$2);
}, retry: (_, _) => null);

// -----------------------------------------------------------------------------
// Community (Chat Rooms & DMs) Providers
// -----------------------------------------------------------------------------

/// Available public and private chat rooms from GET /api/v0/rooms/available.
final slskdAvailableRoomsProvider =
    FutureProvider.autoDispose.family<List<SlskdRoomInfo>, Instance>((
  ref,
  instance,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getAvailableRooms();
}, retry: (_, _) => null);

/// Joined room names from GET /api/v0/rooms/joined, polled while active.
final slskdJoinedRoomNamesProvider =
    FutureProvider.autoDispose.family<List<String>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getJoinedRoomNames();
}), retry: (_, _) => null);

/// Details and recent messages for a joined room from GET /api/v0/rooms/joined/{roomName}.
final slskdRoomDetailProvider =
    FutureProvider.autoDispose.family<SlskdRoom?, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getRoom(arg.$2);
}, retry: (_, _) => null);

/// Room messages for a joined room from GET /api/v0/rooms/joined/{roomName}/messages, polled while active.
final slskdRoomMessagesProvider =
    FutureProvider.autoDispose.family<List<SlskdRoomMessage>, (Instance, String)>((
  ref,
  arg,
) => ref.polled(slskdPollInterval(arg.$1), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getRoomMessages(arg.$2);
}), retry: (_, _) => null);

/// Users present in a joined room from GET /api/v0/rooms/joined/{roomName}/users.
final slskdRoomUsersProvider =
    FutureProvider.autoDispose.family<List<SlskdUserPresence>, (Instance, String)>((
  ref,
  arg,
) async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getRoomUsers(arg.$2);
}, retry: (_, _) => null);

/// Direct message conversations from GET /api/v0/conversations, polled while active.
final slskdConversationsProvider =
    FutureProvider.autoDispose.family<List<SlskdConversation>, Instance>((
  ref,
  instance,
) => ref.polled(slskdPollInterval(instance), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(instance).future);
  return api.getConversations();
}), retry: (_, _) => null);

/// Private messages for a conversation from GET /api/v0/conversations/{username}/messages, polled while active.
final slskdConversationMessagesProvider =
    FutureProvider.autoDispose.family<List<SlskdPrivateMessage>, (Instance, String)>((
  ref,
  arg,
) => ref.polled(slskdPollInterval(arg.$1), () async {
  final SlskdApi api = await ref.watch(slskdApiProvider(arg.$1).future);
  return api.getConversationMessages(arg.$2);
}), retry: (_, _) => null);
