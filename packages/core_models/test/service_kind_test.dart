import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Instances are persisted by enum *name*, and the profile format relies on
  // the order never shifting. Listing every value in order makes appending a
  // new kind a one-line change here while any insertion or reorder fails.
  test('ServiceKind stays append-only', () {
    expect(
      ServiceKind.values.map((ServiceKind k) => k.name),
      <String>[
        'sonarr',
        'radarr',
        'prowlarr',
        'bazarr',
        'seerr',
        'tautulli',
        'jellyfin',
        'emby',
        'plex',
        'qbittorrent',
        'sabnzbd',
        'glances',
        'speedtestTracker',
        'nzbget',
        'deluge',
        'transmission',
        'rtorrent',
      ],
    );
  });

  test('Speedtest Tracker is registered as bearer-auth Analytics service', () {
    expect(ServiceKind.speedtestTracker.displayName, 'Speedtest Tracker');
    expect(ServiceKind.speedtestTracker.role, ServiceRole.analytics);
    expect(ServiceKind.speedtestTracker.authStyle, AuthStyle.bearerToken);
    expect(ServiceKind.speedtestTracker.defaultPort, isNull);
  });

  // rTorrent has no auth of its own: it is protected by whatever proxy sits in
  // front, so credentials are optional HTTP Basic.
  test('rTorrent is registered as a userPass download client', () {
    expect(ServiceKind.rtorrent.displayName, 'rTorrent');
    expect(ServiceKind.rtorrent.role, ServiceRole.downloader);
    expect(ServiceKind.rtorrent.authStyle, AuthStyle.userPass);
    expect(ServiceKind.rtorrent.defaultPort, 8000);
  });

  test('existing services retain their default ports', () {
    expect(ServiceKind.sonarr.defaultPort, 8989);
    expect(ServiceKind.glances.defaultPort, 61208);
  });
}
