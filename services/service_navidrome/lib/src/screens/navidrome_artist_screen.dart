import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navidrome_api.dart';
import '../navidrome_providers.dart';
import '../widgets/navidrome_rating_bar.dart';
import 'navidrome_album_screen.dart';

class NavidromeArtistScreen extends ConsumerWidget {
  const NavidromeArtistScreen({
    required this.instance,
    required this.artistId,
    this.initialArtistName,
    super.key,
  });

  final Instance instance;
  final String artistId;
  final String? initialArtistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<NavidromeArtistDetail> detailAsync =
        ref.watch(navidromeArtistDetailProvider((instance, artistId)));
    final AsyncValue<NavidromeClient> clientAsync =
        ref.watch(navidromeClientProvider(instance));
    final NavidromeClient? client = clientAsync.value;

    final NavidromeArtist? artist = detailAsync.value?.artist;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          if (artist != null) ...<Widget>[
            IconButton(
              icon: Icon(
                (artist.userRating != null && artist.userRating! > 0)
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: (artist.userRating != null && artist.userRating! > 0)
                    ? Colors.amber
                    : null,
              ),
              tooltip: (artist.userRating != null && artist.userRating! > 0)
                  ? 'Rated ${artist.userRating} / 5'
                  : 'Rate',
              onPressed: () {
                showNavidromeRatingModal(
                  context: context,
                  title: 'Rate Artist',
                  subtitle: artist.name,
                  initialRating: artist.userRating ?? 0,
                  onRatingChanged: (int newRating) async {
                    await client?.setRating(
                      artist.id,
                      newRating,
                    );
                    ref.invalidate(
                      navidromeArtistDetailProvider(
                        (instance, artistId),
                      ),
                    );
                    ref.invalidate(navidromeArtistsProvider);
                    ref.invalidate(navidromeAlbumsProvider);
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(
                artist.isStarred
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: artist.isStarred ? Colors.redAccent : null,
              ),
              tooltip: artist.isStarred
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () async {
                final bool willStar = !artist.isStarred;
                try {
                  if (willStar) {
                    await client?.star(artistId: artist.id);
                  } else {
                    await client?.unstar(artistId: artist.id);
                  }
                  ref.invalidate(
                    navidromeArtistDetailProvider((instance, artistId)),
                  );
                  ref.invalidate(navidromeArtistsProvider);
                  ref.invalidate(navidromeAlbumsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update favorite: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: detailAsync.when(
        data: (NavidromeArtistDetail detail) {
          final NavidromeArtist artist = detail.artist;
          final String cleanArtistId = artist.id.startsWith('ar-')
              ? artist.id.substring(3)
              : artist.id;

          // Priority 1: High-res external promotional banner from Last.fm/Spotify (via getArtistInfo2)
          // Priority 2: Direct artistImageUrl from OpenSubsonic extension
          // Priority 3: Navidrome server artist image via 'ar-<artistId>' (or coverArt if it explicitly starts with 'ar-')
          // NEVER fall back to 'al-' album covers or compilation album art!
          String? bannerUrl;
          if (detail.info?.largeImageUrl != null &&
              detail.info!.largeImageUrl!.trim().isNotEmpty) {
            bannerUrl = detail.info!.largeImageUrl!.trim();
          } else if (detail.info?.mediumImageUrl != null &&
              detail.info!.mediumImageUrl!.trim().isNotEmpty) {
            bannerUrl = detail.info!.mediumImageUrl!.trim();
          } else if (artist.artistImageUrl != null &&
              artist.artistImageUrl!.trim().isNotEmpty) {
            bannerUrl = artist.artistImageUrl!.trim();
          } else if (artist.coverArt != null &&
              artist.coverArt!.startsWith('ar-')) {
            bannerUrl = client?.getCoverArtUrl(artist.coverArt, size: 1000);
          } else if (cleanArtistId.isNotEmpty) {
            bannerUrl = client?.getCoverArtUrl('ar-$cleanArtistId', size: 1000);
          }

          final double bannerHeight = MediaQuery.sizeOf(context).height * 0.48;

          return RefreshIndicator(
            onRefresh: () async {
              await hardRefreshNavidrome(ref, instance);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
              // Top Section: Half-page artist banner with bottom fade
              SliverToBoxAdapter(
                child: SizedBox(
                  height: bannerHeight,
                  child: Stack(
                    children: <Widget>[
                      // 1. Background image or artist placeholder
                      Positioned.fill(
                        child: bannerUrl != null
                            ? AtriumNetworkImage(
                                key: ValueKey<String>(bannerUrl),
                                imageUrl: bannerUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 72,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              )
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 72,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                              ),
                      ),
                      // 2. Dim overlay for readability
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      // 3. Bottom gradient fade into surface
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                cs.surface.withValues(alpha: 0.0),
                                cs.surface.withValues(alpha: 0.2),
                                cs.surface.withValues(alpha: 0.7),
                                cs.surface,
                              ],
                              stops: const <double>[0.3, 0.55, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 4. Artist header info at the bottom of the banner
                      Positioned(
                        left: Insets.lg,
                        right: Insets.lg,
                        bottom: Insets.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              artist.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 1.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${detail.albums.length} ${detail.albums.length == 1 ? 'Album' : 'Albums'}',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: cs.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (detail.info?.biography != null &&
                  detail.info!.biography!.trim().isNotEmpty) ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.md,
                    Insets.lg,
                    Insets.xs,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ArtistBiography(
                      biography: detail.info!.biography!,
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Divider(height: 1),
                  ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.md,
                  Insets.lg,
                  Insets.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Albums',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (detail.albums.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('No albums found for this artist'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.xs,
                    Insets.md,
                    Insets.xl,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.76,
                      crossAxisSpacing: Insets.sm,
                      mainAxisSpacing: Insets.sm,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext ctx, int index) {
                        final NavidromeAlbum album = detail.albums[index];
                        final String? albumCoverUrl =
                            client?.getCoverArtUrl(album.coverArt, size: 300);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await pushScreen<void>(
                              context,
                              NavidromeAlbumScreen(
                                instance: instance,
                                albumId: album.id,
                                initialAlbum: album,
                              ),
                            );
                            ref.invalidate(
                              navidromeArtistDetailProvider(
                                (instance, artistId),
                              ),
                            );
                            ref.invalidate(navidromeAlbumsProvider);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AspectRatio(
                                aspectRatio: 1.0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: albumCoverUrl != null
                                      ? AtriumNetworkImage(
                                          imageUrl: albumCoverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                            color: cs.surfaceContainerHighest,
                                            child: const Icon(
                                              Icons.album_rounded,
                                              size: 40,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: cs.surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.album_rounded,
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                album.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                album.year != null ? '${album.year}' : '',
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: detail.albums.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: Insets.md),
              Text('Failed to load artist: $err'),
              const SizedBox(height: Insets.md),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(
                  navidromeArtistDetailProvider((instance, artistId)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistBiography extends StatefulWidget {
  const _ArtistBiography({required this.biography});

  final String biography;

  @override
  State<_ArtistBiography> createState() => _ArtistBiographyState();
}

class _ArtistBiographyState extends State<_ArtistBiography> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String cleanText = widget.biography
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    final bool isLong = cleanText.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'About',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Insets.xs),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Text(
            cleanText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          secondChild: Text(
            cleanText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
        if (isLong) ...<Widget>[
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _expanded ? 'Read less' : 'Read more',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

