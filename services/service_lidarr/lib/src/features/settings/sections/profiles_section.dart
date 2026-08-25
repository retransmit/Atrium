import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';

/// Profiles configuration section (Quality, Metadata, Delay, and Release profiles).
class ProfilesSection extends ConsumerWidget {
  const ProfilesSection({required this.instance, super.key});

  final Instance instance;

  Future<void> _showQualityProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    QualityProfileResource? profile,
  ]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isNew = profile == null;

    QualityProfileResource? baseProfile = profile;
    if (isNew) {
      final AsyncValue<QualityProfileResource> schemaAsync =
          ref.read(lidarrQualityProfileSchemaProvider(instance));
      baseProfile = schemaAsync.value;
      if (baseProfile == null) {
        try {
          final LidarrApi api =
              await ref.read(lidarrApiProvider(instance).future);
          final ApiResponse<QualityProfileResource> resp =
              await api.qualityProfileSchema.getQualityprofileSchema();
          baseProfile = resp.data;
        } catch (_) {}
      }
    }

    if (baseProfile == null && isNew) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to load quality profile template.'),
        ),
      );
      return;
    }

    final TextEditingController nameController =
        TextEditingController(text: isNew ? '' : (baseProfile?.name ?? ''));
    bool upgradeAllowed = baseProfile?.upgradeAllowed ?? true;
    int cutoffId = baseProfile?.cutoff ??
        (baseProfile?.items?.isNotEmpty == true
            ? (baseProfile!.items!.first.quality?.id ??
                baseProfile.items!.first.id ??
                1)
            : 1);

    final List<QualityProfileQualityItemResource> items =
        (baseProfile?.items ?? <QualityProfileQualityItemResource>[])
            .map((QualityProfileQualityItemResource item) => item.copyWith())
            .toList();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setDialogState) {
            final List<Map<String, dynamic>> cutoffOptions =
                <Map<String, dynamic>>[];
            for (final QualityProfileQualityItemResource item in items) {
              if (item.quality != null) {
                cutoffOptions.add(<String, dynamic>{
                  'id': item.quality!.id,
                  'name': item.quality!.name ?? item.name ?? 'Quality',
                });
              } else if (item.items != null && item.items!.isNotEmpty) {
                cutoffOptions.add(<String, dynamic>{
                  'id': item.id ?? 0,
                  'name': item.name ?? 'Group',
                });
              }
            }

            return AlertDialog(
              title:
                  Text(isNew ? 'Add Quality Profile' : 'Edit Quality Profile'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Profile Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      SwitchListTile(
                        title: const Text('Allow Upgrades'),
                        subtitle: const Text(
                          'Download higher quality releases when found',
                        ),
                        value: upgradeAllowed,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => upgradeAllowed = val),
                      ),
                      if (upgradeAllowed && cutoffOptions.isNotEmpty) ...[
                        const SizedBox(height: Insets.xs),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: cutoffOptions.any(
                            (Map<String, dynamic> o) => o['id'] == cutoffId,
                          )
                              ? cutoffId
                              : (cutoffOptions.first['id'] as int?),
                          decoration: const InputDecoration(
                            labelText: 'Upgrade Until (Cutoff)',
                            border: OutlineInputBorder(),
                          ),
                          items: cutoffOptions.map((Map<String, dynamic> o) {
                            return DropdownMenuItem<int>(
                              value: o['id'] as int?,
                              child: Text(o['name'] as String? ?? 'Unknown'),
                            );
                          }).toList(),
                          onChanged: (int? val) {
                            if (val != null) {
                              setDialogState(() => cutoffId = val);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: Insets.md),
                      const Text(
                        'Qualities (Allowed)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Insets.xs),
                      ...items.asMap().entries.map((
                        MapEntry<int, QualityProfileQualityItemResource> entry,
                      ) {
                        final int idx = entry.key;
                        final QualityProfileQualityItemResource qItem =
                            entry.value;
                        final String qName =
                            qItem.quality?.name ?? qItem.name ?? 'Quality';
                        final bool allowed = qItem.allowed ?? true;

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(qName),
                          value: allowed,
                          onChanged: (bool? val) {
                            setDialogState(() {
                              items[idx] =
                                  qItem.copyWith(allowed: val ?? false);
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final String profileName = nameController.text.trim();
                    if (profileName.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a profile name.'),
                        ),
                      );
                      return;
                    }

                    final QualityProfileResource payload =
                        (baseProfile ?? const QualityProfileResource())
                            .copyWith(
                      name: profileName,
                      upgradeAllowed: upgradeAllowed,
                      cutoff: cutoffId,
                      items: items,
                    );

                    try {
                      final LidarrApi api =
                          await ref.read(lidarrApiProvider(instance).future);
                      if (isNew) {
                        final ApiResponse<QualityProfileResource> resp =
                            await api.qualityProfile
                                .postQualityprofile(body: payload);
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to create quality profile',
                          );
                        }
                      } else {
                        final ApiResponse<QualityProfileResource> resp =
                            await api.qualityProfile.putQualityprofileById(
                          id: '${profile.id}',
                          body: payload,
                        );
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to update quality profile',
                          );
                        }
                      }

                      ref.invalidate(lidarrQualityProfilesProvider(instance));
                      if (dCtx.mounted) {
                        Navigator.pop(dCtx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Quality profile ${isNew ? 'added' : 'updated'}!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dCtx.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteQualityProfile(
    BuildContext context,
    WidgetRef ref,
    QualityProfileResource profile,
  ) async {
    final int? id = profile.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete ${profile.name ?? 'Quality Profile'}?'),
        content: Text(
          'Are you sure you want to delete the "${profile.name}" quality profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<void> resp =
          await api.qualityProfile.deleteQualityprofileById(id: id);
      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to delete quality profile',
        );
      }

      ref.invalidate(lidarrQualityProfilesProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Quality profile deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete quality profile: $e')),
      );
    }
  }

  Future<void> _showMetadataProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    MetadataProfileResource? profile,
  ]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isNew = profile == null;

    MetadataProfileResource? baseProfile = profile;
    if (isNew) {
      final AsyncValue<MetadataProfileResource> schemaAsync =
          ref.read(lidarrMetadataProfileSchemaProvider(instance));
      baseProfile = schemaAsync.value;
      if (baseProfile == null) {
        try {
          final LidarrApi api =
              await ref.read(lidarrApiProvider(instance).future);
          final ApiResponse<MetadataProfileResource> resp =
              await api.metadataProfileSchema.getMetadataprofileSchema();
          baseProfile = resp.data;
        } catch (_) {}
      }
    }

    if (baseProfile == null && isNew) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to load metadata profile template.'),
        ),
      );
      return;
    }

    final TextEditingController nameController =
        TextEditingController(text: isNew ? '' : (baseProfile?.name ?? ''));

    final List<ProfilePrimaryAlbumTypeItemResource> primaryTypes =
        (baseProfile?.primaryAlbumTypes ??
                <ProfilePrimaryAlbumTypeItemResource>[])
            .map((ProfilePrimaryAlbumTypeItemResource item) => item.copyWith())
            .toList();
    final List<ProfileSecondaryAlbumTypeItemResource> secondaryTypes =
        (baseProfile?.secondaryAlbumTypes ??
                <ProfileSecondaryAlbumTypeItemResource>[])
            .map(
              (ProfileSecondaryAlbumTypeItemResource item) => item.copyWith(),
            )
            .toList();
    final List<ProfileReleaseStatusItemResource> releaseStatuses =
        (baseProfile?.releaseStatuses ?? <ProfileReleaseStatusItemResource>[])
            .map((ProfileReleaseStatusItemResource item) => item.copyWith())
            .toList();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                isNew ? 'Add Metadata Profile' : 'Edit Metadata Profile',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Profile Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      if (primaryTypes.isNotEmpty) ...[
                        const Text(
                          'Primary Album Types',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.xs),
                        ...primaryTypes.asMap().entries.map((
                          MapEntry<int, ProfilePrimaryAlbumTypeItemResource>
                              entry,
                        ) {
                          final int idx = entry.key;
                          final ProfilePrimaryAlbumTypeItemResource pItem =
                              entry.value;
                          final String title = pItem.albumType?.name ?? 'Type';
                          final bool allowed = pItem.allowed ?? true;

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            value: allowed,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                primaryTypes[idx] =
                                    pItem.copyWith(allowed: val ?? false);
                              });
                            },
                          );
                        }),
                        const SizedBox(height: Insets.md),
                      ],
                      if (secondaryTypes.isNotEmpty) ...[
                        const Text(
                          'Secondary Album Types',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.xs),
                        ...secondaryTypes.asMap().entries.map((
                          MapEntry<int, ProfileSecondaryAlbumTypeItemResource>
                              entry,
                        ) {
                          final int idx = entry.key;
                          final ProfileSecondaryAlbumTypeItemResource sItem =
                              entry.value;
                          final String title = sItem.albumType?.name ?? 'Type';
                          final bool allowed = sItem.allowed ?? false;

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            value: allowed,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                secondaryTypes[idx] =
                                    sItem.copyWith(allowed: val ?? false);
                              });
                            },
                          );
                        }),
                        const SizedBox(height: Insets.md),
                      ],
                      if (releaseStatuses.isNotEmpty) ...[
                        const Text(
                          'Release Statuses',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.xs),
                        ...releaseStatuses.asMap().entries.map((
                          MapEntry<int, ProfileReleaseStatusItemResource> entry,
                        ) {
                          final int idx = entry.key;
                          final ProfileReleaseStatusItemResource rItem =
                              entry.value;
                          final String title =
                              rItem.releaseStatus?.name ?? 'Status';
                          final bool allowed = rItem.allowed ?? true;

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            value: allowed,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                releaseStatuses[idx] =
                                    rItem.copyWith(allowed: val ?? false);
                              });
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final String profileName = nameController.text.trim();
                    if (profileName.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a profile name.'),
                        ),
                      );
                      return;
                    }

                    final MetadataProfileResource payload =
                        (baseProfile ?? const MetadataProfileResource())
                            .copyWith(
                      name: profileName,
                      primaryAlbumTypes: primaryTypes,
                      secondaryAlbumTypes: secondaryTypes,
                      releaseStatuses: releaseStatuses,
                    );

                    try {
                      final LidarrApi api =
                          await ref.read(lidarrApiProvider(instance).future);
                      if (isNew) {
                        final ApiResponse<MetadataProfileResource> resp =
                            await api.metadataProfile
                                .postMetadataprofile(body: payload);
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to create metadata profile',
                          );
                        }
                      } else {
                        final ApiResponse<MetadataProfileResource> resp =
                            await api.metadataProfile.putMetadataprofileById(
                          id: '${profile.id}',
                          body: payload,
                        );
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to update metadata profile',
                          );
                        }
                      }

                      ref.invalidate(lidarrMetadataProfilesProvider(instance));
                      if (dCtx.mounted) {
                        Navigator.pop(dCtx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Metadata profile ${isNew ? 'added' : 'updated'}!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dCtx.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMetadataProfile(
    BuildContext context,
    WidgetRef ref,
    MetadataProfileResource profile,
  ) async {
    final int? id = profile.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete ${profile.name ?? 'Metadata Profile'}?'),
        content: Text(
          'Are you sure you want to delete the "${profile.name}" metadata profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<void> resp =
          await api.metadataProfile.deleteMetadataprofileById(id: id);
      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to delete metadata profile',
        );
      }

      ref.invalidate(lidarrMetadataProfilesProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Metadata profile deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete metadata profile: $e')),
      );
    }
  }

  Future<void> _showDelayProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    DelayProfileResource? profile,
  ]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isNew = profile == null;

    bool enableUsenet = profile?.enableUsenet ?? true;
    bool enableTorrent = profile?.enableTorrent ?? true;
    DownloadProtocol preferredProtocol =
        profile?.preferredProtocol ?? DownloadProtocol.usenet;
    final TextEditingController usenetDelayController =
        TextEditingController(text: '${profile?.usenetDelay ?? 0}');
    final TextEditingController torrentDelayController =
        TextEditingController(text: '${profile?.torrentDelay ?? 0}');
    bool bypassIfHighestQuality = profile?.bypassIfHighestQuality ?? true;
    bool bypassIfAboveScore = profile?.bypassIfAboveCustomFormatScore ?? false;
    final TextEditingController minScoreController = TextEditingController(
      text: '${profile?.minimumCustomFormatScore ?? 0}',
    );
    final List<int> tags = List<int>.from(profile?.tags ?? <int>[]);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setDialogState) {
            final AsyncValue<List<TagResource>> asyncTags =
                ref.watch(lidarrTagsProvider(instance));

            return AlertDialog(
              title: Text(isNew ? 'Add Delay Profile' : 'Edit Delay Profile'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Usenet'),
                        value: enableUsenet,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => enableUsenet = val),
                      ),
                      SwitchListTile(
                        title: const Text('Enable Torrent'),
                        value: enableTorrent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => enableTorrent = val),
                      ),
                      const SizedBox(height: Insets.xs),
                      DropdownButtonFormField<DownloadProtocol>(
                        initialValue: preferredProtocol,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Protocol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DownloadProtocol.usenet,
                            child: Text('Usenet'),
                          ),
                          DropdownMenuItem(
                            value: DownloadProtocol.torrent,
                            child: Text('Torrent'),
                          ),
                        ],
                        onChanged: (DownloadProtocol? val) {
                          if (val != null) {
                            setDialogState(() => preferredProtocol = val);
                          }
                        },
                      ),
                      const SizedBox(height: Insets.sm),
                      TextField(
                        controller: usenetDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Usenet Delay (minutes)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      TextField(
                        controller: torrentDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Torrent Delay (minutes)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      SwitchListTile(
                        title: const Text('Bypass if Highest Quality'),
                        value: bypassIfHighestQuality,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => bypassIfHighestQuality = val),
                      ),
                      SwitchListTile(
                        title: const Text('Bypass if Above CF Score'),
                        value: bypassIfAboveScore,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => bypassIfAboveScore = val),
                      ),
                      if (bypassIfAboveScore) ...[
                        const SizedBox(height: Insets.xs),
                        TextField(
                          controller: minScoreController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Custom Format Score',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: Insets.sm),
                      const Text(
                        'Tags',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Insets.xs),
                      asyncTags.when(
                        data: (List<TagResource> allTags) {
                          if (allTags.isEmpty) {
                            return const Text('No tags available.');
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: allTags.map((TagResource t) {
                              final int? tId = t.id;
                              if (tId == null) return const SizedBox.shrink();
                              final bool isSelected = tags.contains(tId);
                              return FilterChip(
                                label: Text(t.label ?? 'Tag $tId'),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      tags.add(tId);
                                    } else {
                                      tags.remove(tId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const Text('Failed to load tags'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final int usenetDelay =
                        int.tryParse(usenetDelayController.text.trim()) ?? 0;
                    final int torrentDelay =
                        int.tryParse(torrentDelayController.text.trim()) ?? 0;
                    final int minScore =
                        int.tryParse(minScoreController.text.trim()) ?? 0;

                    final DelayProfileResource payload =
                        (profile ?? const DelayProfileResource()).copyWith(
                      enableUsenet: enableUsenet,
                      enableTorrent: enableTorrent,
                      preferredProtocol: preferredProtocol,
                      usenetDelay: usenetDelay,
                      torrentDelay: torrentDelay,
                      bypassIfHighestQuality: bypassIfHighestQuality,
                      bypassIfAboveCustomFormatScore: bypassIfAboveScore,
                      minimumCustomFormatScore: minScore,
                      tags: tags,
                    );

                    try {
                      final LidarrApi api =
                          await ref.read(lidarrApiProvider(instance).future);
                      if (isNew) {
                        final ApiResponse<DelayProfileResource> resp = await api
                            .delayProfile
                            .postDelayprofile(body: payload);
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to create delay profile',
                          );
                        }
                      } else {
                        final ApiResponse<DelayProfileResource> resp =
                            await api.delayProfile.putDelayprofileById(
                          id: '${profile.id}',
                          body: payload,
                        );
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to update delay profile',
                          );
                        }
                      }

                      ref.invalidate(lidarrDelayProfilesProvider(instance));
                      if (dCtx.mounted) {
                        Navigator.pop(dCtx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Delay profile ${isNew ? 'added' : 'updated'}!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dCtx.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDelayProfile(
    BuildContext context,
    WidgetRef ref,
    DelayProfileResource profile,
  ) async {
    final int? id = profile.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Delay Profile?'),
        content: const Text(
          'Are you sure you want to delete this delay profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<void> resp =
          await api.delayProfile.deleteDelayprofileById(id: id);
      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to delete delay profile',
        );
      }

      ref.invalidate(lidarrDelayProfilesProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Delay profile deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete delay profile: $e')),
      );
    }
  }

  Future<void> _showReleaseProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    ReleaseProfileResource? profile,
  ]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isNew = profile == null;

    bool enabled = profile?.enabled ?? true;
    final TextEditingController requiredController = TextEditingController(
      text: (profile?.requiredVal ?? <String>[]).join(', '),
    );
    final TextEditingController ignoredController = TextEditingController(
      text: (profile?.ignored ?? <String>[]).join(', '),
    );
    int? indexerId = profile?.indexerId;
    final List<int> tags = List<int>.from(profile?.tags ?? <int>[]);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setDialogState) {
            final AsyncValue<List<TagResource>> asyncTags =
                ref.watch(lidarrTagsProvider(instance));
            final AsyncValue<List<IndexerResource>> asyncIndexers =
                ref.watch(lidarrIndexersProvider(instance));

            return AlertDialog(
              title:
                  Text(isNew ? 'Add Release Profile' : 'Edit Release Profile'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Enabled'),
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => enabled = val),
                      ),
                      const SizedBox(height: Insets.xs),
                      TextField(
                        controller: requiredController,
                        decoration: const InputDecoration(
                          labelText: 'Must Contain',
                          hintText: 'Comma separated terms (e.g. FLAC, 24bit)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      TextField(
                        controller: ignoredController,
                        decoration: const InputDecoration(
                          labelText: 'Must Not Contain',
                          hintText:
                              'Comma separated terms (e.g. live, bootleg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      asyncIndexers.when(
                        data: (List<IndexerResource> indexers) {
                          return DropdownButtonFormField<int?>(
                            initialValue: indexerId,
                            decoration: const InputDecoration(
                              labelText: 'Indexer',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                child: Text('Any / All Indexers'),
                              ),
                              ...indexers.map((IndexerResource idx) {
                                return DropdownMenuItem<int?>(
                                  value: idx.id,
                                  child: Text(idx.name ?? 'Indexer ${idx.id}'),
                                );
                              }),
                            ],
                            onChanged: (int? val) {
                              setDialogState(() => indexerId = val);
                            },
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: Insets.sm),
                      const Text(
                        'Tags',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Insets.xs),
                      asyncTags.when(
                        data: (List<TagResource> allTags) {
                          if (allTags.isEmpty) {
                            return const Text('No tags available.');
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: allTags.map((TagResource t) {
                              final int? tId = t.id;
                              if (tId == null) return const SizedBox.shrink();
                              final bool isSelected = tags.contains(tId);
                              return FilterChip(
                                label: Text(t.label ?? 'Tag $tId'),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      tags.add(tId);
                                    } else {
                                      tags.remove(tId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const Text('Failed to load tags'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final List<String> reqTerms = requiredController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    final List<String> ignTerms = ignoredController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();

                    final ReleaseProfileResource payload =
                        (profile ?? const ReleaseProfileResource()).copyWith(
                      enabled: enabled,
                      requiredVal: reqTerms,
                      ignored: ignTerms,
                      indexerId: indexerId ?? 0,
                      tags: tags,
                    );

                    try {
                      final LidarrApi api =
                          await ref.read(lidarrApiProvider(instance).future);
                      if (isNew) {
                        final ApiResponse<ReleaseProfileResource> resp =
                            await api.releaseProfile
                                .postReleaseprofile(body: payload);
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to create release profile',
                          );
                        }
                      } else {
                        final ApiResponse<ReleaseProfileResource> resp =
                            await api.releaseProfile.putReleaseprofileById(
                          id: '${profile.id}',
                          body: payload,
                        );
                        if (!resp.isSuccess) {
                          throw Exception(
                            resp.error?.message ??
                                'Failed to update release profile',
                          );
                        }
                      }

                      ref.invalidate(lidarrReleaseProfilesProvider(instance));
                      if (dCtx.mounted) {
                        Navigator.pop(dCtx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Release profile ${isNew ? 'added' : 'updated'}!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dCtx.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReleaseProfile(
    BuildContext context,
    WidgetRef ref,
    ReleaseProfileResource profile,
  ) async {
    final int? id = profile.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Release Profile?'),
        content: const Text(
          'Are you sure you want to delete this release profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<void> resp =
          await api.releaseProfile.deleteReleaseprofileById(id: id);
      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to delete release profile',
        );
      }

      ref.invalidate(lidarrReleaseProfilesProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Release profile deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete release profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<List<QualityProfileResource>> asyncQuality =
        ref.watch(lidarrQualityProfilesProvider(instance));
    final AsyncValue<List<MetadataProfileResource>> asyncMetadata =
        ref.watch(lidarrMetadataProfilesProvider(instance));
    final AsyncValue<List<DelayProfileResource>> asyncDelay =
        ref.watch(lidarrDelayProfilesProvider(instance));
    final AsyncValue<List<ReleaseProfileResource>> asyncRelease =
        ref.watch(lidarrReleaseProfilesProvider(instance));

    // Prefetch schemas for snappy dialogs
    ref.watch(lidarrQualityProfileSchemaProvider(instance));
    ref.watch(lidarrMetadataProfileSchemaProvider(instance));

    return EasyRefresh(
      onRefresh: () async {
        ref.invalidate(lidarrQualityProfilesProvider(instance));
        ref.invalidate(lidarrMetadataProfilesProvider(instance));
        ref.invalidate(lidarrDelayProfilesProvider(instance));
        ref.invalidate(lidarrReleaseProfilesProvider(instance));
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: [
          // 1. Quality Profiles Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.high_quality_outlined,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quality Profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add Quality Profile',
                onPressed: () => _showQualityProfileDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          AsyncValueView<List<QualityProfileResource>>(
            value: asyncQuality,
            data: (List<QualityProfileResource> profiles) {
              if (profiles.isEmpty) {
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No quality profiles found.',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: profiles.map((QualityProfileResource p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: cs.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          p.name ?? 'Profile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (p.upgradeAllowed == true) 'Upgrades Allowed',
                            if (p.cutoff != null) 'Cutoff ID: ${p.cutoff}',
                          ].join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.items != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${p.items!.length} qualities',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Delete Quality Profile',
                              onPressed: () =>
                                  _deleteQualityProfile(context, ref, p),
                            ),
                          ],
                        ),
                        onTap: () => _showQualityProfileDialog(context, ref, p),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: Insets.xl),

          // 2. Metadata Profiles Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Metadata Profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add Metadata Profile',
                onPressed: () => _showMetadataProfileDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          AsyncValueView<List<MetadataProfileResource>>(
            value: asyncMetadata,
            data: (List<MetadataProfileResource> profiles) {
              if (profiles.isEmpty) {
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No metadata profiles found.',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: profiles.map((MetadataProfileResource p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.library_music_outlined,
                            color: cs.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          p.name ?? 'Metadata Profile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (p.primaryAlbumTypes != null)
                              '${p.primaryAlbumTypes!.where((ProfilePrimaryAlbumTypeItemResource t) => t.allowed == true).length} Primary Types',
                            if (p.secondaryAlbumTypes != null)
                              '${p.secondaryAlbumTypes!.where((ProfileSecondaryAlbumTypeItemResource t) => t.allowed == true).length} Secondary Types',
                            if (p.releaseStatuses != null)
                              '${p.releaseStatuses!.where((ProfileReleaseStatusItemResource s) => s.allowed == true).length} Release Statuses',
                          ].join(' • '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete Metadata Profile',
                          onPressed: () =>
                              _deleteMetadataProfile(context, ref, p),
                        ),
                        onTap: () =>
                            _showMetadataProfileDialog(context, ref, p),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: Insets.xl),

          // 3. Delay Profiles Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hourglass_empty_outlined,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delay Profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add Delay Profile',
                onPressed: () => _showDelayProfileDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          AsyncValueView<List<DelayProfileResource>>(
            value: asyncDelay,
            data: (List<DelayProfileResource> delayProfiles) {
              if (delayProfiles.isEmpty) {
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No delay profiles configured.',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: delayProfiles.map((DelayProfileResource dp) {
                  final List<String> protocols = [
                    if (dp.enableUsenet == true)
                      'Usenet (${dp.usenetDelay ?? 0}m)',
                    if (dp.enableTorrent == true)
                      'Torrent (${dp.torrentDelay ?? 0}m)',
                  ];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.hourglass_empty_outlined,
                            color: cs.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          'Preferred: ${dp.preferredProtocol?.name.toUpperCase() ?? 'USENET'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          [
                            protocols.join(' • '),
                            if (dp.bypassIfHighestQuality == true)
                              'Bypass on highest quality',
                            if (dp.bypassIfAboveCustomFormatScore == true)
                              'Bypass CF score >= ${dp.minimumCustomFormatScore ?? 0}',
                          ].join('\n'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete Delay Profile',
                          onPressed: () =>
                              _deleteDelayProfile(context, ref, dp),
                        ),
                        onTap: () => _showDelayProfileDialog(context, ref, dp),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: Insets.xl),

          // 4. Release Profiles Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Release Profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add Release Profile',
                onPressed: () => _showReleaseProfileDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          AsyncValueView<List<ReleaseProfileResource>>(
            value: asyncRelease,
            data: (List<ReleaseProfileResource> releaseProfiles) {
              if (releaseProfiles.isEmpty) {
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No release profiles configured.',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: releaseProfiles.map((ReleaseProfileResource rp) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            rp.enabled == true
                                ? Icons.filter_alt_outlined
                                : Icons.filter_alt_off_outlined,
                            color: cs.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          rp.enabled == true
                              ? 'Release Filter (Active)'
                              : 'Release Filter (Disabled)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rp.requiredVal != null &&
                                rp.requiredVal!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Must Contain: ${rp.requiredVal!.join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                            if (rp.ignored != null &&
                                rp.ignored!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Must Not Contain: ${rp.ignored!.join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete Release Profile',
                          onPressed: () =>
                              _deleteReleaseProfile(context, ref, rp),
                        ),
                        onTap: () =>
                            _showReleaseProfileDialog(context, ref, rp),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
