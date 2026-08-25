import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../state/api_providers.dart';

/// Root folders configured in Lidarr.
final lidarrRootFoldersProvider =
    FutureProvider.autoDispose.family<List<RootFolderResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<RootFolderResource>> resp =
        await api.rootFolder.getRootfolder();
    return unwrapLidarrApiResponse(resp, 'Failed to load root folders');
  },
);

/// Quality profiles configured in Lidarr.
final lidarrQualityProfilesProvider =
    FutureProvider.autoDispose.family<List<QualityProfileResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<QualityProfileResource>> resp =
        await api.qualityProfile.getQualityprofile();
    return unwrapLidarrApiResponse(resp, 'Failed to load quality profiles');
  },
);

/// Metadata profiles configured in Lidarr.
final lidarrMetadataProfilesProvider =
    FutureProvider.autoDispose.family<List<MetadataProfileResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<MetadataProfileResource>> resp =
        await api.metadataProfile.getMetadataprofile();
    return unwrapLidarrApiResponse(resp, 'Failed to load metadata profiles');
  },
);

/// Quality profile schema / default preset provider.
final lidarrQualityProfileSchemaProvider =
    FutureProvider.autoDispose.family<QualityProfileResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<QualityProfileResource> resp =
        await api.qualityProfileSchema.getQualityprofileSchema();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load quality profile schema',
    );
  },
);

/// Metadata profile schema / default preset provider.
final lidarrMetadataProfileSchemaProvider =
    FutureProvider.autoDispose.family<MetadataProfileResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<MetadataProfileResource> resp =
        await api.metadataProfileSchema.getMetadataprofileSchema();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load metadata profile schema',
    );
  },
);

/// Tags configured in Lidarr.
final lidarrTagsProvider =
    FutureProvider.autoDispose.family<List<TagResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<TagResource>> resp = await api.tag.getTag();
    return unwrapLidarrApiResponse(resp, 'Failed to load tags');
  },
);

/// Configured custom formats provider.
final lidarrCustomFormatsProvider =
    FutureProvider.autoDispose.family<List<CustomFormatResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<CustomFormatResource>> resp =
        await api.customFormat.getCustomformat();
    return unwrapLidarrApiResponse(resp, 'Failed to load custom formats');
  },
);

/// Custom format specification schemas provider.
final lidarrCustomFormatSchemaProvider = FutureProvider.autoDispose
    .family<List<CustomFormatSpecificationSchema>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    try {
      final resp = await api.dio.get<dynamic>('/api/v1/customformat/schema');
      if (resp.data is List) {
        return (resp.data as List<dynamic>)
            .map(
              (e) => CustomFormatSpecificationSchema.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return <CustomFormatSpecificationSchema>[];
  },
);

/// Delay profiles provider.
final lidarrDelayProfilesProvider =
    FutureProvider.autoDispose.family<List<DelayProfileResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<DelayProfileResource>> resp =
        await api.delayProfile.getDelayprofile();
    return unwrapLidarrApiResponse(resp, 'Failed to load delay profiles');
  },
);

/// Release profiles provider.
final lidarrReleaseProfilesProvider =
    FutureProvider.autoDispose.family<List<ReleaseProfileResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<ReleaseProfileResource>> resp =
        await api.releaseProfile.getReleaseprofile();
    return unwrapLidarrApiResponse(resp, 'Failed to load release profiles');
  },
);

/// Quality definitions provider.
final lidarrQualityDefinitionsProvider = FutureProvider.autoDispose
    .family<List<QualityDefinitionResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<QualityDefinitionResource>> resp =
        await api.qualityDefinition.getQualitydefinition();
    return unwrapLidarrApiResponse(resp, 'Failed to load quality definitions');
  },
);

/// Track naming configuration provider.
final lidarrNamingConfigProvider =
    FutureProvider.autoDispose.family<NamingConfigResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<NamingConfigResource> resp =
        await api.namingConfig.getConfigNaming();
    return unwrapLidarrApiResponse(resp, 'Failed to load naming config');
  },
);

/// Media management configuration provider.
final lidarrMediaManagementConfigProvider =
    FutureProvider.autoDispose.family<MediaManagementConfigResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<MediaManagementConfigResource> resp =
        await api.mediaManagementConfig.getConfigMediamanagement();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load media management config',
    );
  },
);

/// Metadata consumers provider.
final lidarrMetadataConsumersProvider =
    FutureProvider.autoDispose.family<List<MetadataResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<MetadataResource>> resp =
        await api.metadata.getMetadata();
    return unwrapLidarrApiResponse(resp, 'Failed to load metadata consumers');
  },
);

/// Metadata consumer schemas provider.
final lidarrMetadataConsumerSchemaProvider =
    FutureProvider.autoDispose.family<List<MetadataResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<MetadataResource>> resp =
        await api.metadata.getMetadataSchema();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load metadata consumer schemas',
    );
  },
);

/// Auto-tagging rules provider.
final lidarrAutoTaggingProvider =
    FutureProvider.autoDispose.family<List<AutoTaggingResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<AutoTaggingResource>> resp =
        await api.autoTagging.getAutotagging();
    return unwrapLidarrApiResponse(resp, 'Failed to load auto-tagging rules');
  },
);

/// Host / General configuration provider.
final lidarrHostConfigProvider =
    FutureProvider.autoDispose.family<HostConfigResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<HostConfigResource> resp =
        await api.hostConfig.getConfigHost();
    return unwrapLidarrApiResponse(resp, 'Failed to load general host config');
  },
);

/// Global indexer options configuration provider.
final lidarrIndexerConfigProvider =
    FutureProvider.autoDispose.family<IndexerConfigResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<IndexerConfigResource> resp =
        await api.indexerConfig.getConfigIndexer();
    return unwrapLidarrApiResponse(resp, 'Failed to load indexer options');
  },
);

/// Global download client options configuration provider.
final lidarrDownloadClientConfigProvider =
    FutureProvider.autoDispose.family<DownloadClientConfigResource, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<DownloadClientConfigResource> resp =
        await api.downloadClientConfig.getConfigDownloadclient();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load download client options',
    );
  },
);

/// Configured indexers in Lidarr.
final lidarrIndexersProvider =
    FutureProvider.autoDispose.family<List<IndexerResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<IndexerResource>> resp =
        await api.indexer.getIndexer();
    return unwrapLidarrApiResponse(resp, 'Failed to load indexers');
  },
);

/// Indexer schemas / presets provider.
final lidarrIndexerSchemaProvider =
    FutureProvider.autoDispose.family<List<IndexerResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<IndexerResource>> resp =
        await api.indexer.getIndexerSchema();
    return unwrapLidarrApiResponse(resp, 'Failed to load indexer schemas');
  },
);

/// Configured download clients in Lidarr.
final lidarrDownloadClientsProvider =
    FutureProvider.autoDispose.family<List<DownloadClientResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<DownloadClientResource>> resp =
        await api.downloadClient.getDownloadclient();
    return unwrapLidarrApiResponse(resp, 'Failed to load download clients');
  },
);

/// Download client schemas / presets provider.
final lidarrDownloadClientSchemaProvider =
    FutureProvider.autoDispose.family<List<DownloadClientResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<DownloadClientResource>> resp =
        await api.downloadClient.getDownloadclientSchema();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load download client schemas',
    );
  },
);

/// Configured import lists in Lidarr.
final lidarrImportListsProvider =
    FutureProvider.autoDispose.family<List<ImportListResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<ImportListResource>> resp =
        await api.importList.getImportlist();
    return unwrapLidarrApiResponse(resp, 'Failed to load import lists');
  },
);

/// Import list schemas / presets provider.
final lidarrImportListSchemaProvider =
    FutureProvider.autoDispose.family<List<ImportListResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<ImportListResource>> resp =
        await api.importList.getImportlistSchema();
    return unwrapLidarrApiResponse(resp, 'Failed to load import list schemas');
  },
);

/// Configured notification integrations in Lidarr.
final lidarrNotificationsProvider =
    FutureProvider.autoDispose.family<List<NotificationResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<NotificationResource>> resp =
        await api.notification.getNotification();
    return unwrapLidarrApiResponse(resp, 'Failed to load notifications');
  },
);

/// Notification schemas / presets provider.
final lidarrNotificationSchemaProvider =
    FutureProvider.autoDispose.family<List<NotificationResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<NotificationResource>> resp =
        await api.notification.getNotificationSchema();
    return unwrapLidarrApiResponse(resp, 'Failed to load notification schemas');
  },
);

/// Configured remote path mappings in Lidarr.
final lidarrRemotePathMappingsProvider =
    FutureProvider.autoDispose.family<List<RemotePathMappingResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<RemotePathMappingResource>> resp =
        await api.remotePathMapping.getRemotepathmapping();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load remote path mappings',
    );
  },
);

/// Configured import list exclusions in Lidarr.
final lidarrImportListExclusionsProvider =
    FutureProvider.autoDispose.family<List<ImportListExclusionResource>, Instance>(
  (Ref ref, Instance instance) async {
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<ImportListExclusionResource>> resp =
        await api.importListExclusion.getImportlistexclusion();
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load import list exclusions',
    );
  },
);
