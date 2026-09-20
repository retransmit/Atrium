import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

/// The product name plex.tv shows on the sign-in page and in the account's
/// device list.
const String plexProduct = 'Atrium';

const String _plexAccountBase = 'https://plex.tv';

/// A PIN handed out by plex.tv: the user links it in a browser, and polling
/// it afterwards returns the account token.
class PlexPin {
  const PlexPin({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  factory PlexPin.fromJson(Map<String, dynamic> json) {
    final Object? expires = json['expiresAt'];
    final int seconds = (json['expiresIn'] as num?)?.toInt() ?? 900;
    final DateTime fallback = DateTime.now().add(Duration(seconds: seconds));
    return PlexPin(
      id: '${json['id']}',
      code: '${json['code']}',
      expiresAt: expires is String
          ? (DateTime.tryParse(expires)?.toLocal() ?? fallback)
          : fallback,
    );
  }

  final String id;
  final String code;
  final DateTime expiresAt;

  bool get hasExpired => !DateTime.now().isBefore(expiresAt);
}

/// One way plex.tv says a server can be reached.
class PlexConnection {
  const PlexConnection({
    required this.uri,
    required this.address,
    required this.port,
    required this.protocol,
    required this.local,
    required this.relay,
  });

  factory PlexConnection.fromJson(Map<String, dynamic> json) => PlexConnection(
        uri: (json['uri'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        port: (json['port'] as num?)?.toInt() ?? 32400,
        protocol: (json['protocol'] as String?) ?? 'http',
        local: json['local'] == true,
        relay: json['relay'] == true,
      );

  final String uri;
  final String address;
  final int port;
  final String protocol;
  final bool local;
  final bool relay;
}

/// A server the signed-in account can see.
///
/// [accessToken] is the server's own token rather than the account one. A
/// server somebody shared with you only answers to this, so it is what gets
/// saved on the instance.
class PlexServer {
  const PlexServer({
    required this.name,
    required this.clientIdentifier,
    required this.accessToken,
    required this.owned,
    required this.publicAddressMatches,
    required this.connections,
  });

  factory PlexServer.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['connections'];
    return PlexServer(
      name: (json['name'] as String?)?.trim().isNotEmpty ?? false
          ? (json['name'] as String).trim()
          : 'Plex Media Server',
      clientIdentifier: (json['clientIdentifier'] as String?) ?? '',
      accessToken: (json['accessToken'] as String?) ?? '',
      owned: json['owned'] == true,
      publicAddressMatches: json['publicAddressMatches'] == true,
      connections: <PlexConnection>[
        if (raw is List<Object?>)
          for (final Object? entry in raw)
            if (entry is Map<String, dynamic>) PlexConnection.fromJson(entry),
      ],
    );
  }

  final String name;
  final String clientIdentifier;
  final String accessToken;
  final bool owned;

  /// Whether the account is looking at this from the server's own network.
  /// plex.tv works it out by comparing public addresses, and it is the only
  /// way to know whether a remote address that did not answer is broken or
  /// merely untestable from here.
  final bool publicAddressMatches;

  final List<PlexConnection> connections;
}

/// The two URLs an instance is saved with, worked out from what plex.tv
/// advertises for a server.
class PlexServerUrls {
  const PlexServerUrls({
    this.localUrl,
    this.externalUrl,
    this.usesRelay = false,
    this.externalUnverified = false,
  });

  final String? localUrl;
  final String? externalUrl;

  /// Whether [externalUrl] is a Plex Relay address, which is what a server
  /// with no reachable public address falls back to. It works, but everything
  /// goes through Plex and is capped at 1 Mbps.
  final bool usesRelay;

  /// Whether [externalUrl] is what Plex advertises rather than something that
  /// answered. True only on the server's own network, where a public address
  /// cannot be reached at all, so nothing can be concluded from its silence.
  final bool externalUnverified;
}

/// Turns a server's advertised connections into a local and an external URL.
///
/// On the LAN a plain `http://<ip>:<port>` is preferred over the advertised
/// `.plex.direct` name, because that name resolves a private address over
/// public DNS and routers with rebind protection refuse to answer it. A
/// server set to require secure connections offers no plain connection, and
/// there the `.plex.direct` URI is the only thing that works, so it is used.
///
/// The external URL always takes the advertised URI: the raw public address
/// would fail TLS, since the certificate is issued for the `.plex.direct`
/// name and not for the address behind it.
PlexServerUrls resolvePlexServerUrls(PlexServer server) {
  final List<PlexConnection> direct =
      server.connections.where((PlexConnection c) => !c.relay).toList();
  final List<PlexConnection> locals =
      direct.where((PlexConnection c) => c.local).toList();
  final List<PlexConnection> remotes =
      direct.where((PlexConnection c) => !c.local).toList();

  final PlexConnection? plainLocal = locals.firstWhereOrNull(
    (PlexConnection c) => c.protocol == 'http' && c.address.isNotEmpty,
  );
  final PlexConnection? anyLocal =
      locals.firstWhereOrNull((PlexConnection c) => c.uri.isNotEmpty);
  final String? localUrl = plainLocal != null
      ? 'http://${plainLocal.address}:${plainLocal.port}'
      : anyLocal?.uri;

  final PlexConnection? remote =
      remotes.firstWhereOrNull((PlexConnection c) => c.uri.isNotEmpty);
  final PlexConnection? relay = server.connections
      .firstWhereOrNull((PlexConnection c) => c.relay && c.uri.isNotEmpty);

  return PlexServerUrls(
    localUrl: localUrl,
    externalUrl: remote?.uri ?? relay?.uri,
    usesRelay: remote == null && relay != null,
  );
}

/// Fills in only the addresses that answer from where the user is standing.
///
/// Plex advertises whatever addresses the server can see, which for a server
/// in a Docker bridge network is the container's own address on that bridge:
/// something like 172.18.0.13, which nothing outside the host can reach. Its
/// own clients get around this by trying every connection and keeping what
/// works, so this does the same, all of them at once so one dead address
/// costs no more than the timeout.
///
/// The local URL is left empty unless something answered on it. An address
/// that answers nowhere is worse than none at all: URL selection probes local
/// first, so a dead one buys a timeout on every single call. The external URL
/// is filled from what Plex advertises even unverified, because it is the
/// fallback either way and a phone on the LAN cannot usually reach its own
/// public address (routers rarely turn a connection back on itself).
Future<PlexServerUrls> probePlexServerUrls(
  PlexServer server, {
  Dio? dio,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Dio client = dio ?? Dio();
  client.options
    ..connectTimeout = timeout
    ..receiveTimeout = timeout
    ..validateStatus = (int? status) => status != null && status < 500;

  Future<bool> answers(String url) async {
    if (url.isEmpty) {
      return false;
    }
    try {
      // `identity` is the one route that needs no token, so an answer here
      // says a Plex server is listening without saying anything about auth.
      final String base = url.replaceAll(RegExp(r'/+$'), '');
      await client.get<dynamic>('$base/identity');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The plain address first: see [resolvePlexServerUrls] for why.
  List<String> candidates(PlexConnection c) => <String>[
        if (c.protocol == 'http' && c.address.isNotEmpty)
          'http://${c.address}:${c.port}',
        if (c.uri.isNotEmpty) c.uri,
      ];

  final List<PlexConnection> locals = server.connections
      .where((PlexConnection c) => c.local && !c.relay)
      .toList();
  final List<PlexConnection> remotes = server.connections
      .where((PlexConnection c) => !c.local && !c.relay)
      .toList();
  final List<PlexConnection> relays =
      server.connections.where((PlexConnection c) => c.relay).toList();

  // Preference order, so the first reachable entry of each group wins.
  final List<String> localUrls =
      <String>[for (final PlexConnection c in locals) ...candidates(c)];
  final List<String> remoteUrls =
      <String>[for (final PlexConnection c in remotes) ...candidates(c)];
  final List<String> relayUrls =
      <String>[for (final PlexConnection c in relays) ...candidates(c)];

  final List<String> all = <String>[...localUrls, ...remoteUrls, ...relayUrls];
  final List<bool> reachable =
      await Future.wait(all.map(answers));
  final Set<String> live = <String>{
    for (int i = 0; i < all.length; i++)
      if (reachable[i]) all[i],
  };

  String? firstLive(List<String> urls) =>
      urls.firstWhereOrNull(live.contains);

  final PlexServerUrls advertised = resolvePlexServerUrls(server);
  final String? remote = firstLive(remoteUrls);
  // The relay is a Plex-hosted endpoint on the open internet, so unlike the
  // server's own public address it can be reached from the LAN too. That
  // makes it the one external address that can always be tested.
  final String? relay = firstLive(relayUrls);

  if (remote != null) {
    return PlexServerUrls(localUrl: firstLive(localUrls), externalUrl: remote);
  }
  if (relay != null) {
    return PlexServerUrls(
      localUrl: firstLive(localUrls),
      externalUrl: relay,
      usesRelay: true,
    );
  }

  // Nothing external answered. On the server's own network that says nothing:
  // routers rarely turn a connection back on itself, so the public address
  // could not have answered even if it is perfectly fine. Anywhere else, it
  // had its chance, and an address that does not work should not be written.
  if (!server.publicAddressMatches) {
    return PlexServerUrls(localUrl: firstLive(localUrls));
  }
  return PlexServerUrls(
    localUrl: firstLive(localUrls),
    externalUrl: advertised.externalUrl,
    usesRelay: advertised.usesRelay,
    externalUnverified: advertised.externalUrl != null,
  );
}

/// Where the user signs in for [pin].
///
/// The code rides along in the fragment, so the page links itself and nobody
/// has to read four characters off one screen and type them into another.
/// plex.tv/link stays as the fallback for a browser that will not open.
Uri plexAuthUri({required String clientIdentifier, required String code}) {
  final String query = Uri(
    queryParameters: <String, String>{
      'clientID': clientIdentifier,
      'code': code,
      'context[device][product]': plexProduct,
    },
  ).query;
  return Uri.parse('https://app.plex.tv/auth#?$query');
}

/// A plex.tv call that failed, carrying something worth showing the user.
class PlexAccountException implements Exception {
  const PlexAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// plex.tv's account API, which is a different thing from a media server.
///
/// Signing in never touches the server, so somebody who cannot reach theirs
/// (the usual reason for not having a token in the first place) can still get
/// one, and then read the server's address back off their account.
class PlexAccountApi {
  PlexAccountApi({required this.clientIdentifier, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = _plexAccountBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'X-Plex-Product': plexProduct,
        'X-Plex-Client-Identifier': clientIdentifier,
      });
  }

  /// Identifies this install to plex.tv. The PIN is issued against it, so the
  /// poll has to send the same one or plex.tv answers 404.
  final String clientIdentifier;

  final Dio _dio;

  Future<PlexPin> createPin() async {
    final Object? data = await _send(
      () => _dio.post<dynamic>(
        '/api/v2/pins',
        queryParameters: <String, dynamic>{'strong': 'true'},
      ),
    );
    if (data is! Map<String, dynamic>) {
      throw const PlexAccountException('plex.tv returned an unexpected reply.');
    }
    return PlexPin.fromJson(data);
  }

  /// The account token once the user has linked [pin], null while they have
  /// not got round to it yet.
  Future<String?> pollPin(PlexPin pin) async {
    final Object? data = await _send(
      () => _dio.get<dynamic>(
        '/api/v2/pins/${pin.id}',
        queryParameters: <String, dynamic>{'code': pin.code},
      ),
    );
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final String? token = data['authToken'] as String?;
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Every media server the account can see, owned or shared.
  Future<List<PlexServer>> getServers(String token) async {
    final Object? data = await _send(
      () => _dio.get<dynamic>(
        '/api/v2/resources',
        queryParameters: <String, dynamic>{
          'includeHttps': 1,
          'includeRelay': 1,
        },
        options: Options(headers: <String, String>{'X-Plex-Token': token}),
      ),
    );
    if (data is! List<Object?>) {
      throw const PlexAccountException('plex.tv returned an unexpected reply.');
    }
    return <PlexServer>[
      for (final Object? entry in data)
        if (entry is Map<String, dynamic> && _providesServer(entry))
          PlexServer.fromJson(entry),
    ];
  }

  void close() => _dio.close();

  static bool _providesServer(Map<String, dynamic> json) =>
      ((json['provides'] as String?) ?? '').split(',').contains('server');

  Future<Object?> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final Response<dynamic> resp = await call();
      return resp.data;
    } on DioException catch (e) {
      throw PlexAccountException(_describe(e));
    }
  }

  static String _describe(DioException error) {
    final int? status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Plex rejected the sign-in. Try signing in again.';
    }
    if (status == 404) {
      return 'Plex forgot this sign-in. Start again.';
    }
    if (status != null) {
      return 'plex.tv answered HTTP $status.';
    }
    return 'Could not reach plex.tv.';
  }
}
