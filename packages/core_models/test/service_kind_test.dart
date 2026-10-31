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
        'adguardHome',
        'aria2',
        'cleanuparr',
        'slskd',
      ],
    );
  });

  test('Ombi is registered as an apiKey request service', () {
    expect(ServiceKind.ombi.displayName, 'Ombi');
    expect(ServiceKind.ombi.tagline, 'Requests');
    expect(ServiceKind.ombi.isBeta, isFalse);
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
    expect(ServiceKind.unraid.isBeta, isFalse);
    expect(ServiceKind.lidarr.isBeta, isFalse);
    expect(ServiceKind.navidrome.isBeta, isFalse);
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

  test('AdGuard Home is registered as a userPass analytics service', () {
    expect(ServiceKind.adguardHome.displayName, 'AdGuard Home');
    expect(ServiceKind.adguardHome.tagline, 'Network-wide blocking');
    expect(ServiceKind.adguardHome.isBeta, isFalse);
    expect(ServiceKind.adguardHome.defaultPort, 80);
    expect(ServiceKind.adguardHome.authStyle, AuthStyle.userPass);
    expect(ServiceKind.adguardHome.role, ServiceRole.analytics);
    expect(ServiceKind.adguardHome.acceptsTorrents, isFalse);
  });

  test('aria2 is registered as an apiKey download client', () {
    expect(ServiceKind.aria2.displayName, 'aria2');
    expect(ServiceKind.aria2.tagline, 'Download client');
    expect(ServiceKind.aria2.isBeta, isTrue);
    expect(ServiceKind.aria2.defaultPort, 6800);
    // The credential is the daemon's `--rpc-secret`, which travels as the
    // first RPC parameter rather than as a header.
    expect(ServiceKind.aria2.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.aria2.role, ServiceRole.downloader);
    // aria2 speaks BitTorrent as well as plain HTTP.
    expect(ServiceKind.aria2.acceptsTorrents, isTrue);
  });

  test('Cleanuparr is registered as an apiKey automation service', () {
    expect(ServiceKind.cleanuparr.displayName, 'Cleanuparr');
    expect(ServiceKind.cleanuparr.tagline, 'Malware blocker & cleaner');
    expect(ServiceKind.cleanuparr.isBeta, isTrue);
    expect(ServiceKind.cleanuparr.defaultPort, 11011);
    expect(ServiceKind.cleanuparr.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.cleanuparr.role, ServiceRole.automation);
    expect(ServiceKind.cleanuparr.acceptsTorrents, isFalse);
  });

  test('slskd is registered as an apiKey downloader service', () {
    expect(ServiceKind.slskd.displayName, 'slskd');
    expect(ServiceKind.slskd.tagline, 'Soulseek client');
    expect(ServiceKind.slskd.isBeta, isTrue);
    expect(ServiceKind.slskd.defaultPort, 5030);
    expect(ServiceKind.slskd.authStyle, AuthStyle.apiKey);
    expect(ServiceKind.slskd.role, ServiceRole.downloader);
    expect(ServiceKind.slskd.acceptsTorrents, isFalse);
  });

  test('existing services retain their default ports', () {
    expect(ServiceKind.sonarr.defaultPort, 8989);
    expect(ServiceKind.glances.defaultPort, 61208);
  });
}
