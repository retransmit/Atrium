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
        'navidrome',
        'gluetun',
        'ombi',
        'myspeed',
      ],
    );
  });

  test('Ombi is registered as a beta apiKey request service', () {
    expect(ServiceKind.ombi.displayName, 'Ombi');
    expect(ServiceKind.ombi.tagline, 'Requests');
    expect(ServiceKind.ombi.isBeta, isTrue);
    expect(ServiceKind.ombi.defaultPort, 3579);
    expect(ServiceKind.ombi.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.ombi.role, ServiceRole.requests);
    expect(ServiceKind.ombi.acceptsTorrents, isFalse);
  });

  test('MySpeed is registered as an apiKey analytics service', () {
    expect(ServiceKind.myspeed.displayName, 'MySpeed');
    expect(ServiceKind.myspeed.tagline, 'Internet speed');
    expect(ServiceKind.myspeed.isBeta, isFalse);
    expect(ServiceKind.myspeed.defaultPort, 5216);
    expect(ServiceKind.myspeed.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.myspeed.role, ServiceRole.analytics);
    expect(ServiceKind.myspeed.acceptsTorrents, isFalse);
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
    // Out of beta since its parity pass against the web UI.
    expect(ServiceKind.transmission.isBeta, isFalse);
    expect(ServiceKind.deluge.isBeta, isTrue);
    expect(ServiceKind.rtorrent.isBeta, isTrue);
    expect(ServiceKind.sonarr.isBeta, isFalse);
    expect(ServiceKind.qbittorrent.isBeta, isFalse);
    // Tracearr graduated out of beta once its rebuild landed.
    expect(ServiceKind.tracearr.isBeta, isFalse);
    expect(ServiceKind.unraid.isBeta, isTrue);
    expect(ServiceKind.navidrome.isBeta, isTrue);
    expect(ServiceKind.myspeed.isBeta, isFalse);
  });

  test('Navidrome is registered as userPass mediaServer service', () {
    expect(ServiceKind.navidrome.displayName, 'Navidrome');
    expect(ServiceKind.navidrome.role, ServiceRole.mediaServer);
    expect(ServiceKind.navidrome.authStyle, AuthStyle.userPass);
    expect(ServiceKind.navidrome.defaultPort, 4533);
  });

  test('Gluetun is registered as an apiKey analytics service', () {
    expect(ServiceKind.gluetun.displayName, 'Gluetun');
    expect(ServiceKind.gluetun.role, ServiceRole.analytics);
    expect(ServiceKind.gluetun.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.gluetun.defaultPort, 8000);
    expect(ServiceKind.gluetun.isBeta, isFalse);
  });

  test('existing services retain their default ports', () {
    expect(ServiceKind.sonarr.defaultPort, 8989);
    expect(ServiceKind.glances.defaultPort, 61208);
  });
}
