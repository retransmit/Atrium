import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_client.dart';
import 'jellyfin_providers.dart';
import 'models/jellyfin_item.dart';
import 'models/jellyfin_remote_image.dart';

class JellyfinRemoteImagesScreen extends ConsumerStatefulWidget {
  const JellyfinRemoteImagesScreen({
    required this.instance,
    required this.itemId,
    this.imageType = 'Primary',
    super.key,
  });

  final Instance instance;
  final String itemId;
  final String imageType;

  @override
  ConsumerState<JellyfinRemoteImagesScreen> createState() =>
      _JellyfinRemoteImagesScreenState();
}

class _JellyfinRemoteImagesScreenState
    extends ConsumerState<JellyfinRemoteImagesScreen> {
  bool _isSaving = false;

  Future<void> _setImage(String imageUrl) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final JellyfinClient client =
          await ref.read(jellyfinClientProvider(widget.instance).future);
      final JellyfinItem? oldItem = ref
          .read(jellyfinItemDetailsProvider((widget.instance, widget.itemId)))
          .value;
      String? oldTaggedUrl;
      if (oldItem != null) {
        if (widget.imageType == 'Backdrop') {
          oldTaggedUrl = client.backdropImageUrl(oldItem);
        } else if (widget.imageType == 'Primary') {
          oldTaggedUrl = client.imageUrl(oldItem);
        } else if (widget.imageType == 'Banner') {
          oldTaggedUrl = client.bannerImageUrl(oldItem);
        }
      }

      print('--- STARTING REMOTE IMAGE CHANGE ---');
      print('Type: ${widget.imageType}');
      print('Old Tagged URL: $oldTaggedUrl');

      await client.setRemoteImage(widget.itemId, imageUrl, widget.imageType);

      // Evict untagged URL from cache for sessions that don't use tags
      final String untaggedUrl =
          client.untaggedImageUrl(widget.itemId, widget.imageType);
      await CachedNetworkImage.evictFromCache(untaggedUrl);

      if (oldTaggedUrl != null) {
        await CachedNetworkImage.evictFromCache(oldTaggedUrl);
      }

      // Give the server time to download and apply the new image
      // We poll until the tag actually changes, or timeout after 5 seconds.
      int attempts = 0;
      while (attempts < 10) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final JellyfinItem updatedItem = await client.getItemDetails(widget.itemId);
        String? newTaggedUrl;
        if (widget.imageType == 'Backdrop') {
          newTaggedUrl = client.backdropImageUrl(updatedItem);
        } else if (widget.imageType == 'Primary') {
          newTaggedUrl = client.imageUrl(updatedItem);
        } else if (widget.imageType == 'Banner') {
          newTaggedUrl = client.bannerImageUrl(updatedItem);
        }
        
        if (newTaggedUrl != oldTaggedUrl) {
          print('Polling attempt $attempts: Success! New Tagged URL: $newTaggedUrl');
          break; // The tag has successfully changed!
        } else {
          print('Polling attempt $attempts: Tag did not change. URL: $newTaggedUrl');
        }
        attempts++;
      }

      print('--- INVALIDATING PROVIDERS ---');
      if (!mounted) return;

      // Invalidate relevant providers to force refresh of the image
      ref.invalidate(
          jellyfinItemDetailsProvider((widget.instance, widget.itemId)));
      ref.invalidate(jellyfinItemsProvider);
      ref.invalidate(jellyfinLibraryItemsProvider);
      ref.invalidate(jellyfinFastSessionsProvider(widget.instance));
      ref.invalidate(jellyfinSessionsProvider(widget.instance));

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.imageType} updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          showCloseIcon: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update ${widget.imageType.toLowerCase()}: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          showCloseIcon: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JellyfinRemoteImage>> imagesAsync = ref.watch(
      jellyfinRemoteImagesProvider(
          (widget.instance, widget.itemId, widget.imageType)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${widget.imageType}'),
      ),
      body: Stack(
        children: <Widget>[
          AsyncValueView<List<JellyfinRemoteImage>>(
            value: imagesAsync,
            onRetry: () => ref.invalidate(
              jellyfinRemoteImagesProvider(
                  (widget.instance, widget.itemId, widget.imageType)),
            ),
            data: (List<JellyfinRemoteImage> images) {
              if (images.isEmpty) {
                return const Center(child: Text('No alternate images found.'));
              }
              return GridView.builder(
                padding: const EdgeInsets.all(Insets.lg),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.imageType == 'Primary' ? 3 : 2,
                  childAspectRatio:
                      widget.imageType == 'Primary' ? 2 / 3 : 16 / 9,
                  crossAxisSpacing: Insets.md,
                  mainAxisSpacing: Insets.md,
                ),
                itemCount: images.length,
                itemBuilder: (BuildContext context, int index) {
                  final JellyfinRemoteImage image = images[index];
                  final String? url = image.url ?? image.thumbnailUrl;
                  if (url == null) return const SizedBox.shrink();

                  return InkWell(
                    onTap: () => _setImage(url),
                    borderRadius: Radii.card,
                    child: ClipRRect(
                      borderRadius: Radii.card,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext context, String url) =>
                            Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Center(
                            child: ExpressiveProgressIndicator(),
                          ),
                        ),
                        errorWidget:
                            (BuildContext context, String url, dynamic error) =>
                                Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: ExpressiveProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
