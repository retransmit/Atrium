import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Artwork carries the instance's credential in a header, never in the URL,
/// because a reverse proxy writes the whole request line to its access log.
/// These pin which kinds get which header, and that it goes nowhere else.
void main() {
  tearDown(ArtworkHeaders.reset);

  Instance instance(
    ServiceKind kind,
    InstanceAuth auth, {
    String local = 'http://media.example.test:7878',
    String external = '',
    Map<String, String> headers = const <String, String>{},
  }) =>
      Instance(
        id: kind.name,
        name: kind.name,
        kind: kind,
        localUrl: local,
        externalUrl: external,
        urlMode: UrlMode.auto,
        auth: auth,
        customHeaders: headers,
      );

  void use(List<Instance> instances) => ArtworkHeaders.update(
        instances: instances,
        global: const <String, String>{},
      );

  const String poster =
      'http://media.example.test:7878/api/v3/mediacover/1/poster-500.jpg';

  for (final ServiceKind kind in <ServiceKind>[
    ServiceKind.radarr,
    ServiceKind.sonarr,
    ServiceKind.lidarr,
  ]) {
    test('${kind.name} artwork carries the api key as X-Api-Key', () {
      use(<Instance>[
        instance(kind, const InstanceAuth.apiKey(apiKey: 'secret')),
      ]);
      expect(
        ArtworkHeaders.forUrl(poster),
        <String, String>{'X-Api-Key': 'secret'},
      );
    });
  }

  test('Plex artwork carries the token as X-Plex-Token', () {
    use(<Instance>[
      instance(
        ServiceKind.plex,
        const InstanceAuth.plexToken(token: 'plex-secret'),
        local: 'http://plex.example.test:32400',
      ),
    ]);
    expect(
      ArtworkHeaders.forUrl(
        'http://plex.example.test:32400/library/metadata/1/thumb/2',
      ),
      <String, String>{'X-Plex-Token': 'plex-secret'},
    );
  });

  test('it reaches the external url too', () {
    use(<Instance>[
      instance(
        ServiceKind.radarr,
        const InstanceAuth.apiKey(apiKey: 'secret'),
        external: 'https://radarr.example.org',
      ),
    ]);
    expect(
      ArtworkHeaders.forUrl(
        'https://radarr.example.org/api/v3/mediacover/1/poster-500.jpg',
      ),
      <String, String>{'X-Api-Key': 'secret'},
    );
  });

  test('a default port written out still matches', () {
    // The connection resolver builds the base with Uri.parse, which drops
    // :443 and :80, so the artwork URL does not have the port the user typed.
    // Missing that match now costs the poster, not just a proxy header.
    use(<Instance>[
      instance(
        ServiceKind.radarr,
        const InstanceAuth.apiKey(apiKey: 'secret'),
        local: 'http://192.168.0.10:80',
        external: 'https://radarr.example.org:443/',
      ),
    ]);
    for (final String base in <String>[
      Uri.parse('http://192.168.0.10:80').toString(),
      Uri.parse('https://radarr.example.org:443/').toString(),
    ]) {
      expect(
        ArtworkHeaders.forUrl('${base.replaceAll(RegExp(r'/$'), '')}'
            '/api/v3/mediacover/1/poster-500.jpg'),
        <String, String>{'X-Api-Key': 'secret'},
        reason: base,
      );
    }
  });

  test('a kind whose artwork Atrium does not build sends no key', () {
    use(<Instance>[
      instance(ServiceKind.prowlarr, const InstanceAuth.apiKey(apiKey: 'p')),
    ]);
    expect(ArtworkHeaders.forUrl(poster), isNull);
  });

  test('an empty key sends no header', () {
    use(<Instance>[
      instance(ServiceKind.radarr, const InstanceAuth.apiKey(apiKey: '')),
    ]);
    expect(ArtworkHeaders.forUrl(poster), isNull);
  });

  test('the key never goes to a third party', () {
    use(<Instance>[
      instance(ServiceKind.radarr, const InstanceAuth.apiKey(apiKey: 'secret')),
    ]);
    expect(
      ArtworkHeaders.forUrl('https://image.tmdb.org/t/p/w500/abc.jpg'),
      isNull,
    );
  });

  test('a key does not spill onto another instance on the same host', () {
    // Radarr at the root, Jellyfin on a sub-path with nothing of its own to
    // send. Jellyfin's artwork must not pick up Radarr's key on the way.
    use(<Instance>[
      instance(
        ServiceKind.radarr,
        const InstanceAuth.apiKey(apiKey: 'secret'),
        local: 'https://home.example.test',
      ),
      instance(
        ServiceKind.jellyfin,
        const InstanceAuth.userPass(username: 'u', password: 'p'),
        local: 'https://home.example.test/jellyfin',
      ),
    ]);
    expect(
      ArtworkHeaders.forUrl(
        'https://home.example.test/jellyfin/Items/1/Images/Primary',
      ),
      isNull,
    );
    expect(
      ArtworkHeaders.forUrl(
        'https://home.example.test/api/v3/mediacover/1/poster.jpg',
      ),
      <String, String>{'X-Api-Key': 'secret'},
    );
  });

  test('the service key wins over a custom header of the same name', () {
    // The Dio auth interceptor runs after the custom headers and overwrites
    // them, so artwork has to agree or it would carry a different key.
    use(<Instance>[
      instance(
        ServiceKind.radarr,
        const InstanceAuth.apiKey(apiKey: 'secret'),
        headers: const <String, String>{
          'X-Api-Key': 'typed-by-hand',
          'Proxy-Authorization': 'Bearer p',
        },
      ),
    ]);
    expect(
      ArtworkHeaders.forUrl(poster),
      <String, String>{'X-Api-Key': 'secret', 'Proxy-Authorization': 'Bearer p'},
    );
  });

  group('session headers', () {
    const String jf = 'http://jellyfin.example.test:8096';
    const String image = '$jf/Items/abc/Images/Primary?maxHeight=420';

    Instance jellyfin({Map<String, String> headers = const <String, String>{}}) =>
        instance(
          ServiceKind.jellyfin,
          const InstanceAuth.userPass(username: 'u', password: 'p'),
          local: jf,
          headers: headers,
        );

    test('a signed-in client puts its token on its own artwork', () {
      use(<Instance>[jellyfin()]);
      ArtworkHeaders.setSession('$jf/', <String, String>{'X-Emby-Token': 't'});
      expect(ArtworkHeaders.forUrl(image), <String, String>{'X-Emby-Token': 't'});
      expect(
        ArtworkHeaders.forUrl('https://image.tmdb.org/t/p/w500/abc.jpg'),
        isNull,
      );
    });

    test('it sits beside the custom headers and wins a clash', () {
      use(<Instance>[
        jellyfin(
          headers: const <String, String>{
            'Authorization': 'Basic proxy',
            'CF-Access-Client-Id': 'id',
          },
        ),
      ]);
      ArtworkHeaders.setSession(
        jf,
        <String, String>{'Authorization': 'MediaBrowser Token="t"'},
      );
      expect(ArtworkHeaders.forUrl(image), <String, String>{
        'Authorization': 'MediaBrowser Token="t"',
        'CF-Access-Client-Id': 'id',
      });
    });

    test('a profile refresh keeps it', () {
      use(<Instance>[jellyfin()]);
      ArtworkHeaders.setSession(jf, <String, String>{'X-Emby-Token': 't'});
      use(<Instance>[jellyfin()]);
      expect(ArtworkHeaders.forUrl(image), <String, String>{'X-Emby-Token': 't'});
    });

    test('signing out clears it', () {
      use(<Instance>[jellyfin()]);
      ArtworkHeaders.setSession(jf, <String, String>{'X-Emby-Token': 't'});
      ArtworkHeaders.setSession(jf, null);
      expect(ArtworkHeaders.forUrl(image), isNull);
    });

    test('removing the instance drops its token', () {
      use(<Instance>[jellyfin()]);
      ArtworkHeaders.setSession(jf, <String, String>{'X-Emby-Token': 't'});
      use(<Instance>[]);
      expect(ArtworkHeaders.forUrl(image), isNull);
    });
  });
}
