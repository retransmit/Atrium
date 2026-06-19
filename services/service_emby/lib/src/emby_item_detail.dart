import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emby_client.dart';
import 'emby_deep_link.dart';
import 'emby_providers.dart';
import 'emby_season_screen.dart';
import 'models/emby_item.dart';

class EmbyItemDetailScreen extends ConsumerWidget {
  const EmbyItemDetailScreen({
    required this.instance,
    required this.itemId,
    super.key,
  });

  final Instance instance;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EmbyItem> itemAsync =
        ref.watch(embyItemDetailsProvider((instance, itemId)));
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          if (itemAsync.hasValue && client != null) ...<Widget>[
            IconButton(
              icon: Icon(
                itemAsync.value!.userData?.played == true
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
              ),
              onPressed: () async {
                final toggle = ref.read(embyToggleWatchedProvider(instance));
                await toggle(itemId, !(itemAsync.value!.userData?.played == true));
              },
            ),
            IconButton(
              icon: Icon(
                itemAsync.value!.userData?.isFavorite == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: itemAsync.value!.userData?.isFavorite == true
                    ? Colors.red
                    : null,
              ),
              onPressed: () async {
                final bool isFav =
                    itemAsync.value!.userData?.isFavorite == true;
                await client.markFavorite(itemId, !isFav);
                ref.invalidate(embyItemDetailsProvider((instance, itemId)));
                ref.invalidate(embyFavoritesProvider(instance));
              },
            ),
          ],
        ],
      ),
      body: AsyncValueView<EmbyItem>(
        value: itemAsync,
        onRetry: () =>
            ref.invalidate(embyItemDetailsProvider((instance, itemId))),
        data: (EmbyItem item) {
          final String? backdropUrl = client?.backdropImageUrl(item);
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: backdropUrl != null
                    ? SizedBox(
                        height: 320,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.45,
                                child: CachedNetworkImage(
                                  imageUrl: backdropUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.black54,
                                      Colors.transparent,
                                      Theme.of(context).scaffoldBackgroundColor,
                                    ],
                                    stops: const <double>[0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _Header(item: item, client: client),
                            ),
                          ],
                        ),
                      )
                    : SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Insets.lg),
                          child: _Header(item: item, client: client),
                        ),
                      ),
              ),
              if (item.overview != null && item.overview!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: _ExpandableOverview(text: item.overview!),
                  ),
                ),
              if (item.people.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PeopleRow(item: item, client: client),
                ),
              if (item.type == 'Series') ...<Widget>[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Insets.lg),
                    child: Divider(),
                  ),
                ),
                _SeasonsGrid(instance: instance, seriesId: item.id),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: Insets.xl),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.client});

  final EmbyItem item;
  final EmbyClient? client;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? posterUrl = client?.imageUrl(item, maxHeight: 600);

    // Runtime is in ticks (1 tick = 100ns = 0.0001 ms = 0.0000001 s).
    final int minutes = item.runTimeTicks != null
        ? (item.runTimeTicks! ~/ 10000000) ~/ 60
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (posterUrl != null)
            ClipRRect(
              borderRadius: Radii.card,
              child: CachedNetworkImage(
                imageUrl: posterUrl,
                width: 140,
                height: 210,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 140,
              height: 210,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: Radii.card,
              ),
              child: const Icon(Icons.movie, size: 48),
            ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (item.seriesName != null)
                  Text(
                    item.seriesName!,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                if (item.seriesName != null)
                  const SizedBox(height: 4),
                Text(
                  (item.seriesName != null && item.indexNumber != null)
                      ? 'Episode ${item.indexNumber} - ${item.name}'
                      : item.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: Insets.xs),
                Wrap(
                  spacing: Insets.sm,
                  children: <Widget>[
                    if (item.productionYear != null)
                      Text('${item.productionYear}',
                          style: theme.textTheme.bodyMedium,),
                    if (minutes > 0)
                      Text('$minutes min', style: theme.textTheme.bodyMedium),
                    if (item.officialRating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2,),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.officialRating!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (item.communityRating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            item.communityRating!.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (client != null) {
                        launchEmbyDeepLink(context, client!, item.id);
                      }
                    },
                    icon: Icon(item.type == 'Series' || item.type == 'Movie' ? Icons.play_arrow : Icons.play_circle_fill),
                    label: Text(item.type == 'Series' || item.type == 'Movie' ? 'Watch' : 'Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.item, required this.client});

  final EmbyItem item;
  final EmbyClient? client;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Text(
            'Cast & Crew',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            itemCount: item.people.length,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
            itemBuilder: (BuildContext context, int index) {
              final EmbyPerson person = item.people[index];
              final String b = client?.baseUrl.toString().replaceAll(RegExp(r'/+$'), '') ?? '';
              final String? personImageUrl = person.primaryImageTag != null
                  ? '$b/Items/${person.id}/Images/Primary?tag=${person.primaryImageTag}&quality=90&maxWidth=200'
                  : null;

              return SizedBox(
                width: 100,
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: personImageUrl != null
                          ? CachedNetworkImageProvider(personImageUrl)
                          : null,
                      child: personImageUrl == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      person.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (person.role != null)
                      Text(
                        person.role!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeasonsGrid extends ConsumerWidget {
  const _SeasonsGrid({required this.instance, required this.seriesId});

  final Instance instance;
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmbyItem>> seasonsAsync =
        ref.watch(embySeasonsProvider((instance, seriesId)));
    final EmbyClient? client = ref.watch(embyClientProvider(instance)).value;
    final ThemeData theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: AsyncValueView<List<EmbyItem>>(
        value: seasonsAsync,
        onRetry: () => ref.invalidate(embySeasonsProvider((instance, seriesId))),
        data: (List<EmbyItem> seasons) {
          if (seasons.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.lg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: Insets.md,
                mainAxisSpacing: Insets.md,
              ),
              itemCount: seasons.length,
              itemBuilder: (BuildContext context, int index) {
                final EmbyItem season = seasons[index];
                final String? posterUrl = client?.imageUrl(season, maxHeight: 300);

                return InkWell(
                  borderRadius: Radii.card,
                  onTap: () {
                    pushScreen<void>(
                      context,
                      EmbySeasonScreen(
                        instance: instance,
                        seasonId: season.id,
                        seasonName: season.name,
                        seasonImageUrl: posterUrl,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: Radii.card,
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.tv),
                                ),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        season.name,
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExpandableOverview extends StatefulWidget {
  const _ExpandableOverview({required this.text});
  final String text;

  @override
  State<_ExpandableOverview> createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<_ExpandableOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.text,
          style: theme.textTheme.bodyLarge,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        const SizedBox(height: Insets.sm),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              _expanded ? 'Read Less' : 'Read More',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
