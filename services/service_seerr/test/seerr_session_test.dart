import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr that keeps sessions the way the real one does: a sign-in sets a
/// `connect.sid` cookie, every API call needs a live one or is refused with
/// 403, and `auth/me` answers whoever the session belongs to.
class _FakeSeerr implements HttpClientAdapter {
  _FakeSeerr({
    this.localDisabled = false,
    this.held = false,
  });

  static const String email = 'kid@example.com';
  static const String username = 'kid';
  static const String password = 'pw-ok';
  static const String apiKey = 'key-ok';

  /// Answers `auth/local` with Seerr's "sign-in is disabled" 500.
  final bool localDisabled;

  /// Holds each sign-in until [releaseSignIn].
  final bool held;
  Completer<void> _gate = Completer<void>();

  final List<RequestOptions> asked = <RequestOptions>[];
  final Set<String> _live = <String>{};
  int _issued = 0;

  int get signIns => asked
      .where(
        (RequestOptions o) =>
            o.path.contains('auth/local') || o.path.contains('auth/jellyfin'),
      )
      .length;

  List<RequestOptions> askedFor(String path) =>
      asked.where((RequestOptions o) => o.path.endsWith(path)).toList();

  /// Ends every session, as a Seerr restart or a cookie expiry would.
  void expireSessions() => _live.clear();

  void releaseSignIn() {
    _gate.complete();
    _gate = Completer<void>();
  }

  /// The session the request carries: the first `connect.sid`, as Express
  /// reads it.
  String? _session(RequestOptions o) {
    final Object? header = o.headers['cookie'];
    if (header is! String) {
      return null;
    }
    for (final String part in header.split(';')) {
      final String c = part.trim();
      if (c.startsWith('connect.sid=')) {
        return c.substring('connect.sid='.length);
      }
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options);
    final String path = options.path;
    final Map<String, dynamic> body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};

    if (path.endsWith('auth/local')) {
      if (held) {
        await _gate.future;
      }
      if (localDisabled) {
        return _json(
          <String, dynamic>{
            'error': 'Password sign-in is disabled.',
          },
          500,
        );
      }
      if (body['email'] != email || body['password'] != password) {
        return _json(<String, dynamic>{'message': 'Access denied.'}, 403);
      }
      return _signedIn();
    }
    if (path.endsWith('auth/jellyfin')) {
      if (body.containsKey('hostname')) {
        return _json(
          <String, dynamic>{
            'error': 'Jellyfin hostname already configured',
          },
          500,
        );
      }
      if (body['username'] != username || body['password'] != password) {
        return _json(<String, dynamic>{'message': 'InvalidCredentials'}, 401);
      }
      return _signedIn();
    }

    final bool byKey = options.headers['X-Api-Key'] == apiKey;
    final String? sid = _session(options);
    if (!byKey && (sid == null || !_live.contains(sid))) {
      return _json(
        <String, dynamic>{
          'error': 'You do not have permission to access this endpoint',
        },
        403,
      );
    }
    if (path.endsWith('auth/me')) {
      return _json(
        <String, dynamic>{
          'id': byKey ? 1 : 7,
          'displayName': byKey ? 'Owner' : 'Kid',
          'permissions': byKey ? 2 : 32,
        },
        200,
      );
    }
    if (path.contains('/approve')) {
      // A real permission refusal: the session is fine, the user is not.
      return _json(
        <String, dynamic>{
          'message': 'You do not have permission to access this endpoint',
        },
        403,
      );
    }
    if (path.endsWith('request/count')) {
      return _json(<String, dynamic>{'total': 3}, 200);
    }
    return _json(<String, dynamic>{}, 404);
  }

  ResponseBody _signedIn() {
    final String sid = 's${++_issued}';
    _live.add(sid);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'id': 7}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'set-cookie': <String>['connect.sid=$sid; Path=/; HttpOnly'],
      },
    );
  }

  ResponseBody _json(Map<String, dynamic> data, int status) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A [SeerrApi] over [seerr] with [auth], wired the way the app wires it.
SeerrApi _api(_FakeSeerr seerr, InstanceAuth auth) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://seerr.test:5055/'))
    ..httpClientAdapter = seerr;
  if (auth case InstanceAuthApiKey(:final String apiKey)) {
    dio.options.headers['X-Api-Key'] = apiKey;
  }
  attachSeerrSession(dio, auth);
  return SeerrApi(dio);
}

const InstanceAuth _local = InstanceAuth.cookieLogin(
  username: _FakeSeerr.email,
  password: _FakeSeerr.password,
);

const InstanceAuth _mediaServer = InstanceAuth.userPass(
  username: _FakeSeerr.username,
  password: _FakeSeerr.password,
);

void main() {
  group('SeerrSignIn', () {
    test('reads a local account from a cookie login and back', () {
      final SeerrSignIn signIn = SeerrSignIn.fromAuth(_local)!;
      expect(signIn.kind, SeerrAccountKind.local);
      expect(signIn.username, _FakeSeerr.email);
      expect(signIn.toAuth(), _local);
    });

    test('reads a Jellyfin or Emby account from a username login and back',
        () {
      final SeerrSignIn signIn = SeerrSignIn.fromAuth(_mediaServer)!;
      expect(signIn.kind, SeerrAccountKind.mediaServer);
      expect(signIn.toAuth(), _mediaServer);
    });

    test('has none for an API key', () {
      expect(
        SeerrSignIn.fromAuth(const InstanceAuth.apiKey(apiKey: 'k')),
        isNull,
      );
    });
  });

  group('session', () {
    test('a local account signs in with its email before the first call',
        () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrUser me = await _api(seerr, _local).me();

      expect(me.id, 7);
      final List<RequestOptions> signIns = seerr.askedFor('auth/local');
      expect(signIns, hasLength(1));
      expect(signIns.single.data, <String, String>{
        'email': _FakeSeerr.email,
        'password': _FakeSeerr.password,
      });
      expect(seerr.asked.first.path, endsWith('auth/local'));
    });

    test('a Jellyfin or Emby account signs in with only its credentials',
        () async {
      final _FakeSeerr seerr = _FakeSeerr();
      await _api(seerr, _mediaServer).me();

      final List<RequestOptions> signIns = seerr.askedFor('auth/jellyfin');
      expect(signIns, hasLength(1));
      // Seerr refuses a hostname once its media server is set up.
      expect(signIns.single.data, <String, String>{
        'username': _FakeSeerr.username,
        'password': _FakeSeerr.password,
      });
    });

    test('calls made together share one sign-in', () async {
      final _FakeSeerr seerr = _FakeSeerr(held: true);
      final SeerrApi api = _api(seerr, _local);

      final Future<List<Object>> calls = Future.wait(<Future<Object>>[
        api.me(),
        api.getRequestCounts(),
        api.me(),
      ]);
      await pumpEventQueue();
      seerr.releaseSignIn();
      await calls;

      expect(seerr.signIns, 1);
    });

    test('a later call reuses the session', () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(seerr, _local);
      await api.me();
      await api.getRequestCounts();
      await api.me();

      expect(seerr.signIns, 1);
    });

    test('an expired session signs in again and the call goes through',
        () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(seerr, _local);
      await api.me();
      seerr.expireSessions();

      final SeerrCounts counts = await api.getRequestCounts();

      expect(counts.total, 3);
      expect(seerr.signIns, 2);
      // The retry carried the new session alone, not the dead one first.
      final RequestOptions retry = seerr.askedFor('request/count').last;
      expect(retry.headers['cookie'], 'connect.sid=s2');
    });

    test('a refused action with a live session is not signed in again',
        () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(seerr, _local);
      await api.me();

      await expectLater(api.approve(4), throwsA(isA<NetworkAuthException>()));

      expect(seerr.signIns, 1);
      expect(seerr.askedFor('/approve'), hasLength(1));
    });

    test('a wrong password reads as a rejected sign-in', () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(
        seerr,
        const InstanceAuth.cookieLogin(
          username: _FakeSeerr.email,
          password: 'wrong',
        ),
      );

      await expectLater(
        api.me(),
        throwsA(
          isA<NetworkAuthException>().having(
            (NetworkAuthException e) => e.message,
            'message',
            'Seerr rejected the sign-in. Check the email and password.',
          ),
        ),
      );
      // The refused sign-in is not tried again on its own.
      expect(seerr.signIns, 1);
      expect(seerr.askedFor('auth/me'), isEmpty);
    });

    test('refused credentials are not sent again', () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(
        seerr,
        const InstanceAuth.userPass(
          username: _FakeSeerr.username,
          password: 'wrong',
        ),
      );

      // As the polled request list would, over and over.
      for (int i = 0; i < 3; i++) {
        await expectLater(
          api.getRequestCounts(),
          throwsA(
            isA<NetworkAuthException>().having(
              (NetworkAuthException e) => e.message,
              'message',
              startsWith('Seerr rejected the sign-in.'),
            ),
          ),
        );
      }

      // Each try would reach Jellyfin, which locks the account after three.
      expect(seerr.signIns, 1);
      expect(seerr.askedFor('request/count'), isEmpty);
    });

    test('a switched-off sign-in method is tried again later', () async {
      final _FakeSeerr seerr = _FakeSeerr(localDisabled: true);
      final SeerrApi api = _api(seerr, _local);

      await expectLater(api.me(), throwsA(isA<NetworkAuthException>()));
      await expectLater(api.me(), throwsA(isA<NetworkAuthException>()));

      expect(seerr.signIns, 2);
    });

    test('a wrong Jellyfin password reads as a rejected sign-in', () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrApi api = _api(
        seerr,
        const InstanceAuth.userPass(
          username: _FakeSeerr.username,
          password: 'wrong',
        ),
      );

      await expectLater(
        api.me(),
        throwsA(
          isA<NetworkAuthException>().having(
            (NetworkAuthException e) => e.message,
            'message',
            startsWith('Seerr rejected the sign-in. Check the username'),
          ),
        ),
      );
    });

    test('a switched-off sign-in method says so', () async {
      final _FakeSeerr seerr = _FakeSeerr(localDisabled: true);

      await expectLater(
        _api(seerr, _local).me(),
        throwsA(
          isA<NetworkAuthException>().having(
            (NetworkAuthException e) => e.message,
            'message',
            'Seerr refused the sign-in: Password sign-in is disabled.',
          ),
        ),
      );
    });

    test('an API key never signs in', () async {
      final _FakeSeerr seerr = _FakeSeerr();
      final SeerrUser me = await _api(
        seerr,
        const InstanceAuth.apiKey(apiKey: _FakeSeerr.apiKey),
      ).me();

      expect(me.id, 1);
      expect(seerr.signIns, 0);
    });
  });
}
