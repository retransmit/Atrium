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
        'tracearr',
        'beszel',
        'dashdot',
        'lidarr',
        'unraid',
      ],
    );
  });

  test('Lidarr is registered as apiKey automation service', () {
    expect(ServiceKind.lidarr.displayName, 'Lidarr');
    expect(ServiceKind.lidarr.role, ServiceRole.automation);
    expect(ServiceKind.lidarr.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.lidarr.defaultPort, 8686);
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

  // Monitoring, not automation: it watches playback on Plex/Jellyfin/Emby,
  // which is Tautulli's job rather than the *arr family's.
  test('Tracearr is registered as an apiKey analytics service', () {
    expect(ServiceKind.tracearr.displayName, 'Tracearr');
    expect(ServiceKind.tracearr.role, ServiceRole.analytics);
    expect(ServiceKind.tracearr.authStyle, AuthStyle.apiKey);
    // Upstream's own default; its compose maps ${PORT:-3000}:3000.
    expect(ServiceKind.tracearr.defaultPort, 3000);
  });

  test('newer integrations are flagged beta; stable ones are not', () {
    expect(ServiceKind.transmission.isBeta, isTrue);
    expect(ServiceKind.deluge.isBeta, isTrue);
    expect(ServiceKind.rtorrent.isBeta, isTrue);
    expect(ServiceKind.sonarr.isBeta, isFalse);
    expect(ServiceKind.qbittorrent.isBeta, isFalse);
    // Tracearr graduated out of beta once its rebuild landed.
    expect(ServiceKind.tracearr.isBeta, isFalse);
    expect(ServiceKind.unraid.isBeta, isTrue);
  });

  test('existing services retain their default ports', () {
    expect(ServiceKind.sonarr.defaultPort, 8989);
    expect(ServiceKind.glances.defaultPort, 61208);
  });
}
