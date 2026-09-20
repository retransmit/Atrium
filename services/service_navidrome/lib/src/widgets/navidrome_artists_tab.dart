import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navidrome_api.dart';
import '../navidrome_providers.dart';
import '../screens/navidrome_artist_screen.dart';

/// Modern Artists tab featuring alphabetical section headers with gradient badges
/// and M3 metadata pills.
class NavidromeArtistsTab extends ConsumerStatefulWidget {
  const NavidromeArtistsTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<NavidromeArtistsTab> createState() =>
      _NavidromeArtistsTabState();
}

class _NavidromeArtistsTabState extends ConsumerState<NavidromeArtistsTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final NavidromeClient? client =
        ref.watch(navidromeClientProvider(widget.instance)).value;
    final AsyncValue<List<NavidromeArtistIndex>> artistsAsync =
        ref.watch(navidromeArtistsProvider(widget.instance));

    return EasyRefresh(
      onRefresh: () async {
        await hardRefreshNavidrome(ref, widget.instance);
      },
      child: artistsAsync.when(
        data: (List<NavidromeArtistIndex> indexes) {
          final List<NavidromeArtistIndex> nonEmptyGroups =
              indexes.where((NavidromeArtistIndex g) => g.artists.isNotEmpty).toList();

          if (nonEmptyGroups.isEmpty) {
            return const Center(child: Text('No artists found'));
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(
                child: SizedBox(height: Insets.xs),
              ),

              // Content Groups
              for (final NavidromeArtistIndex group in nonEmptyGroups) ...<Widget>[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(theme, cs, group),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext ctx, int idx) {
                      return _buildArtistRow(
                        ctx,
                        theme,
                        cs,
                        group.artists[idx],
                        client,
                      );
                    },
                    childCount: group.artists.length,
                  ),
                ),
              ],

              // Bottom padding clearance for navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(
          child: Text('Failed to load artists: $err'),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    ColorScheme cs,
    NavidromeArtistIndex group,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  cs.primaryContainer,
                  cs.primaryContainer.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              group.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${group.artists.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    NavidromeArtist artist,
    NavidromeClient? client,
  ) {
    final String cleanId =
        artist.id.startsWith('ar-') ? artist.id.substring(3) : artist.id;
    final String artistArtId =
        (artist.coverArt != null && artist.coverArt!.startsWith('ar-'))
            ? artist.coverArt!
            : 'ar-$cleanId';
    final String? coverUrl =
        (artist.artistImageUrl != null && artist.artistImageUrl!.isNotEmpty)
            ? artist.artistImageUrl
            : client?.getCoverArtUrl(artistArtId, size: 160);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            pushScreen<void>(
              context,
              NavidromeArtistScreen(
                instance: widget.instance,
                artistId: artist.id,
                initialArtistName: artist.name,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: 8,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: coverUrl != null
                      ? AtriumNetworkImage(
                          imageUrl: coverUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            size: 26,
                            color: cs.onPrimaryContainer,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 26,
                          color: cs.onPrimaryContainer,
                        ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.album_rounded,
                              size: 12,
                              color: cs.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${artist.albumCount} ${artist.albumCount == 1 ? 'Album' : 'Albums'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
