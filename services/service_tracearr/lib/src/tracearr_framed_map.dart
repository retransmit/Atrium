import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TracearrFramedMap extends StatefulWidget {
  const TracearrFramedMap({
    required this.initialCenter,
    required this.markers,
    this.initialZoom = 11.0,
    this.borderRadius = 16.0,
    this.isFullscreen = false,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final double borderRadius;
  final bool isFullscreen;

  @override
  State<TracearrFramedMap> createState() => _TracearrFramedMapState();
}

class _TracearrFramedMapState extends State<TracearrFramedMap> {
  final MapController _mapController = MapController();

  void _zoomIn() {
    final double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _resetView() {
    _mapController.move(widget.initialCenter, widget.initialZoom);
  }

  void _toggleFullscreen() {
    if (widget.isFullscreen) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext context) => Scaffold(
            body: TracearrFramedMap(
              initialCenter: _mapController.camera.center,
              initialZoom: _mapController.camera.zoom,
              markers: widget.markers,
              borderRadius: 0.0,
              isFullscreen: true,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final String tileUrl = isDark
        ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          children: <Widget>[
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: widget.initialZoom,
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.atrium.app',
                ),
                MarkerLayer(markers: widget.markers),
              ],
            ),
            // Subtle edge vignette overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: RadialGradient(
                      radius: 1.15,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.transparent,
                        theme.colorScheme.surface.withValues(alpha: 0.4),
                        theme.colorScheme.surface.withValues(alpha: 0.75),
                      ],
                      stops: const <double>[0.0, 0.65, 0.88, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Floating interactive controls
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ControlButton(
                      icon: Icons.add,
                      tooltip: 'Zoom in',
                      onTap: _zoomIn,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 8,
                      endIndent: 8,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    _ControlButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom out',
                      onTap: _zoomOut,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 8,
                      endIndent: 8,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    _ControlButton(
                      icon: Icons.my_location,
                      tooltip: 'Reset view',
                      onTap: _resetView,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 8,
                      endIndent: 8,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    _ControlButton(
                      icon: widget.isFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      tooltip: widget.isFullscreen
                          ? 'Exit full screen'
                          : 'Full screen',
                      onTap: _toggleFullscreen,
                    ),
                  ],
                ),
              ),
            ),
            // Top close button when in fullscreen mode
            if (widget.isFullscreen)
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _ControlButton(
                      icon: Icons.close,
                      tooltip: 'Close full screen',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class TracearrMarkerUser {
  const TracearrMarkerUser({
    required this.username,
    this.avatarUrl,
    this.sessionCount = 1,
  });

  final String username;
  final String? avatarUrl;
  final int sessionCount;
}

void showTracearrUsersBottomSheet(
  BuildContext context,
  String title,
  List<TracearrMarkerUser> users, {
  String? coordinates,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _TracearrUsersBottomSheet(
      title: title,
      users: users,
      coordinates: coordinates,
    ),
  );
}

class _TracearrUsersBottomSheet extends StatelessWidget {
  const _TracearrUsersBottomSheet({
    required this.title,
    required this.users,
    this.coordinates,
  });

  final String title;
  final List<TracearrMarkerUser> users;
  final String? coordinates;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.location_on,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (coordinates != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.gps_fixed,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              coordinates!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${users.length} ${users.length == 1 ? 'User' : 'Users'}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final TracearrMarkerUser user = users[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        backgroundImage: user.avatarUrl != null
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: 28,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active at this location',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${user.sessionCount} ${user.sessionCount == 1 ? 'stream' : 'streams'}',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class TracearrMapMarkerBadge extends StatelessWidget {
  const TracearrMapMarkerBadge({
    required this.users,
    this.locationTitle,
    this.coordinates,
    this.onTap,
    super.key,
  });

  final List<TracearrMarkerUser> users;
  final String? locationTitle;
  final String? coordinates;
  final VoidCallback? onTap;

  Widget _buildAvatar(String? url, ThemeData theme, {double size = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: theme.colorScheme.surfaceContainerHigh,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: size * 0.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildFacePile(ThemeData theme) {
    final List<TracearrMarkerUser> displayUsers = users.take(3).toList();
    if (displayUsers.isEmpty) return _buildAvatar(null, theme);
    if (displayUsers.length == 1) {
      return _buildAvatar(displayUsers.first.avatarUrl, theme);
    }

    const double iconSize = 24.0;
    const double step = 16.0;
    final double totalWidth = iconSize + (displayUsers.length - 1) * step;

    return SizedBox(
      width: totalWidth,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < displayUsers.length; i++)
            Positioned(
              left: i * step,
              top: 0,
              child: _buildAvatar(displayUsers[i].avatarUrl, theme),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String displayText;
    if (users.isEmpty) {
      displayText = 'Unknown';
    } else if (users.length == 1) {
      final TracearrMarkerUser user = users.first;
      displayText = user.sessionCount > 1
          ? '${user.username} (${user.sessionCount})'
          : user.username;
    } else {
      displayText = '${users.length} Users';
    }

    return GestureDetector(
      onTap: onTap ??
          (locationTitle != null && users.isNotEmpty
              ? () => showTracearrUsersBottomSheet(
                    context,
                    locationTitle!,
                    users,
                    coordinates: coordinates,
                  )
              : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFacePile(theme),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
