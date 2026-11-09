import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/generated.dart';
import '../lidarr_api.dart';
import '../lidarr_artwork.dart';

/// Helper to unwrap [ApiResponse] and throw [LidarrException] on failure.
T unwrapLidarrApiResponse<T>(ApiResponse<T> resp, String defaultMessage) {
  final T? data = resp.data;
  if (resp.isSuccess && data != null) {
    return data;
  }
  throw LidarrException(
    resp.error?.message ?? defaultMessage,
    statusCode: resp.statusCode,
    error: resp.error,
  );
}

/// How often the artist library refreshes while watched.
const Duration lidarrLibraryPollInterval = Duration(seconds: 60);

/// How often the download queue refreshes while watched.
const Duration lidarrQueuePollInterval = Duration(seconds: 15);

/// Instance-scoped [LidarrApi] provider bound to Atrium networking.
final lidarrApiProvider = FutureProvider.family<LidarrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  // Artwork is built outside any provider, so it learns here which of the
  // instance's URLs this connection resolved to.
  LidarrArtwork.rememberBaseUrl(instance, dio.options.baseUrl);
  return LidarrApi(dio);
});
