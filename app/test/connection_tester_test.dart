import 'dart:typed_data';

import 'package:atrium/src/connection_test/connection_test_result.dart';
import 'package:atrium/src/connection_test/connection_tester.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health maps to a ConnectionTestResult', () {
    expect(
      connectionResultFromHealth(Health.ok).outcome,
      ConnectionOutcome.connected,
    );
    expect(
      connectionResultFromHealth(Health.warning).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromHealth(Health.error).outcome,
      ConnectionOutcome.unreachable,
    );
  });

  test('errors map to a ConnectionTestResult', () {
    expect(
      connectionResultFromError(const NetworkAuthException('rejected')).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromError(Exception('boom')).outcome,
      ConnectionOutcome.unreachable,
    );
  });

  group('Gluetun', () {
    const Instance gluetun = Instance(
      id: 'gluetun',
      name: 'Gluetun',
      kind: ServiceKind.gluetun,
      localUrl: 'http://gluetun.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

    Future<ConnectionOutcome> testAnswering(int status, String body) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          dioFactoryProvider.overrideWithValue(
            _AnsweringDioFactory(status: status, body: body),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ConnectionTestResult result =
          await container.read(connectionTesterProvider).test(
                candidate: gluetun,
                url: UrlMode.forceLocal,
              );
      return result.outcome;
    }

    test('a stopped VPN still tests as connected', () async {
      // The status dot warns while the VPN is down, but the URL and the key
      // are right, which is all Test connection is asking.
      expect(
        await testAnswering(200, '{"status":"stopped"}'),
        ConnectionOutcome.connected,
      );
    });

    test('a refused key still fails', () async {
      expect(
        await testAnswering(401, 'Unauthorized'),
        ConnectionOutcome.authFailed,
      );
    });
  });

  group('AdGuard Home', () {
    const Instance adguard = Instance(
      id: 'adguard',
      name: 'AdGuard Home',
      kind: ServiceKind.adguardHome,
      localUrl: 'http://adguard.test',
      externalUrl: 'https://adguard.example.test',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.userPass(username: 'admin', password: 'wrong'),
    );

    /// A tester whose every request is answered with [status] and [body],
    /// and the server that counts those requests.
    (ConnectionTester, _CountingDioFactory) testerAnswering(
      int status,
      String body, {
      String contentType = Headers.jsonContentType,
      DateTime Function()? now,
    }) {
      final _CountingDioFactory server = _CountingDioFactory(
        status: status,
        body: body,
        contentType: contentType,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          dioFactoryProvider.overrideWithValue(server),
          if (now != null)
            connectionTesterProvider
                .overrideWith((Ref ref) => ConnectionTester(ref, now: now)),
        ],
      );
      addTearDown(container.dispose);
      return (container.read(connectionTesterProvider), server);
    }

    test('a sign-in that works tests as connected', () async {
      final (ConnectionTester tester, _CountingDioFactory server) =
          testerAnswering(200, '{"version":"v0.107.79","running":true}');

      final ConnectionTestResult result =
          await tester.test(candidate: adguard, url: UrlMode.forceLocal);

      expect(result.outcome, ConnectionOutcome.connected);
      expect(server.requests, 1);
    });

    test('a refused sign-in says what AdGuard Home does about wrong tries',
        () async {
      final (ConnectionTester tester, _) = testerAnswering(401, '');

      final ConnectionTestResult result =
          await tester.test(candidate: adguard, url: UrlMode.forceLocal);

      expect(result.outcome, ConnectionOutcome.authFailed);
      expect(result.message, contains('15 minutes'));
    });

    test('the second address does not resend a sign-in just refused',
        () async {
      // The form tests the local address and then the external one. Each
      // wrong password counts towards the lockout, so one press must cost
      // one try, not two.
      final (ConnectionTester tester, _CountingDioFactory server) =
          testerAnswering(401, '');

      final ConnectionTestResult local =
          await tester.test(candidate: adguard, url: UrlMode.forceLocal);
      final ConnectionTestResult external =
          await tester.test(candidate: adguard, url: UrlMode.forceExternal);

      expect(local.outcome, ConnectionOutcome.authFailed);
      expect(external.outcome, ConnectionOutcome.authFailed);
      // And it says so, rather than claim the second address refused it.
      expect(external.message, contains('Not tried'));
      expect(server.requests, 1);
    });

    test('anything changed on the form is tried', () async {
      final (ConnectionTester tester, _CountingDioFactory server) =
          testerAnswering(401, '');
      await tester.test(candidate: adguard, url: UrlMode.forceLocal);

      // A corrected password.
      await tester.test(
        candidate: adguard.copyWith(
          auth: const InstanceAuth.userPass(
            username: 'admin',
            password: 'another',
          ),
        ),
        url: UrlMode.forceLocal,
      );
      expect(server.requests, 2);

      // A corrected address: the same sign-in may be right for that server.
      await tester.test(
        candidate: adguard.copyWith(localUrl: 'http://other.test'),
        url: UrlMode.forceLocal,
      );
      expect(server.requests, 3);
    });

    test('the same sign-in is tried again once a moment has passed', () async {
      DateTime clock = DateTime(2026, 10, 7, 12);
      final (ConnectionTester tester, _CountingDioFactory server) =
          testerAnswering(401, '', now: () => clock);

      await tester.test(candidate: adguard, url: UrlMode.forceLocal);
      clock = clock.add(const Duration(seconds: 29));
      await tester.test(candidate: adguard, url: UrlMode.forceLocal);
      expect(server.requests, 1);

      clock = clock.add(const Duration(seconds: 2));
      await tester.test(candidate: adguard, url: UrlMode.forceLocal);
      expect(server.requests, 2);
    });

    test('no sign-in entered on a server that wants one says so', () async {
      // Nothing was sent that the server counts as a wrong try, so there is
      // no lockout to warn about and nothing to hold back: both addresses
      // are tried.
      final (ConnectionTester tester, _CountingDioFactory server) =
          testerAnswering(401, '');
      final Instance blank = adguard.copyWith(
        auth: const InstanceAuth.userPass(username: '', password: ''),
      );

      final ConnectionTestResult local =
          await tester.test(candidate: blank, url: UrlMode.forceLocal);
      final ConnectionTestResult external =
          await tester.test(candidate: blank, url: UrlMode.forceExternal);

      expect(local.outcome, ConnectionOutcome.authFailed);
      expect(
        local.message,
        'This AdGuard Home asks for a sign-in. Enter its username and '
        'password',
      );
      expect(external.message, local.message);
      expect(server.requests, 2);
    });

    test('a web page at that address is not AdGuard Home', () async {
      // A proxy's sign-in page, or some other server altogether.
      final (ConnectionTester tester, _) = testerAnswering(
        200,
        '<html><body>Sign in</body></html>',
        contentType: 'text/html',
      );

      final ConnectionTestResult result =
          await tester.test(candidate: adguard, url: UrlMode.forceLocal);

      expect(result.outcome, ConnectionOutcome.authFailed);
      expect(
        result.message,
        'Reachable, but AdGuard Home did not answer at this address',
      );
    });

    test('an address with no AdGuard Home API behind it says so', () async {
      // What a wrong base path gets, from AdGuard Home itself or from
      // whatever else is listening there.
      final (ConnectionTester tester, _) = testerAnswering(
        404,
        '404 page not found\n',
        contentType: 'text/plain; charset=utf-8',
      );

      final ConnectionTestResult result =
          await tester.test(candidate: adguard, url: UrlMode.forceLocal);

      expect(result.outcome, ConnectionOutcome.authFailed);
      expect(
        result.message,
        'Reachable, but AdGuard Home did not answer at this address',
      );
    });
  });

  group('slskd', () {
    const Instance slskdWithKey = Instance(
      id: 'slskd-1',
      name: 'slskd',
      kind: ServiceKind.slskd,
      localUrl: 'http://slskd.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'secret-key'),
    );

    const Instance slskdNoKey = Instance(
      id: 'slskd-2',
      name: 'slskd',
      kind: ServiceKind.slskd,
      localUrl: 'http://slskd.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: ''),
    );

    Future<ConnectionTestResult> testSlskd(
      Instance candidate,
      ResponseBody Function(RequestOptions options) handler,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          dioFactoryProvider.overrideWithValue(
            _SlskdDioFactory(handler: handler),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(connectionTesterProvider).test(
            candidate: candidate,
            url: UrlMode.forceLocal,
          );
    }

    test('a valid key tests as connected', () async {
      final ConnectionTestResult result = await testSlskd(
        slskdWithKey,
        (RequestOptions options) => ResponseBody.fromString(
          '{"version":"0.20.0"}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      expect(result.outcome, ConnectionOutcome.connected);
      expect(result.message, 'Connected');
    });

    test('an invalid key tests as authFailed with guidance', () async {
      final ConnectionTestResult result = await testSlskd(
        slskdWithKey,
        (RequestOptions options) => ResponseBody.fromString(
          '{"error":"Unauthorized"}',
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      expect(result.outcome, ConnectionOutcome.authFailed);
      expect(
        result.message,
        contains('Verify the API key matches SLSKD_API_KEY'),
      );
    });

    test('no key with auth enabled prompts the user for API key', () async {
      final ConnectionTestResult result = await testSlskd(
        slskdNoKey,
        (RequestOptions options) => ResponseBody.fromString(
          '{"error":"Unauthorized"}',
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      expect(result.outcome, ConnectionOutcome.authFailed);
      expect(
        result.message,
        contains('this slskd server has authentication enabled'),
      );
    });

    test('no key with auth disabled (SLSKD_NO_AUTH) connects successfully', () async {
      final ConnectionTestResult result = await testSlskd(
        slskdNoKey,
        (RequestOptions options) => ResponseBody.fromString(
          '{"version":"0.26.2"}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      expect(result.outcome, ConnectionOutcome.connected);
      expect(result.message, 'Connected (no auth required)');
    });

    test('a login page in front of slskd does not test as connected', () async {
      // A forward-auth proxy answers an unauthenticated request with its
      // portal: a 200 web page, not the API.
      final ConnectionTestResult result = await testSlskd(
        slskdWithKey,
        (RequestOptions options) => ResponseBody.fromString(
          '<!doctype html><html><body>Sign in</body></html>',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
          },
        ),
      );

      expect(result.outcome, ConnectionOutcome.authFailed);
    });
  });
}

class _SlskdDioFactory implements DioFactory {
  _SlskdDioFactory({required this.handler});

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<Dio> create(Instance instance) async =>
      Dio(BaseOptions(baseUrl: 'http://slskd.test/'))
        ..httpClientAdapter = _SlskdAdapter(handler);
}

class _SlskdAdapter implements HttpClientAdapter {
  _SlskdAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

/// Hands out a Dio that answers every request with one status and body,
/// labelled `text/plain` the way Gluetun labels everything.
class _AnsweringDioFactory implements DioFactory {
  _AnsweringDioFactory({required this.status, required this.body});

  final int status;
  final String body;

  @override
  Future<Dio> create(Instance instance) async =>
      Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
        ..httpClientAdapter = _Answer(status: status, body: body);
}

class _Answer implements HttpClientAdapter {
  _Answer({required this.status, required this.body});

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Hands out Dios that all answer with one status and body, and counts the
/// requests that reach them, across every Dio it made.
class _CountingDioFactory implements DioFactory {
  _CountingDioFactory({
    required this.status,
    required this.body,
    required this.contentType,
  });

  final int status;
  final String body;
  final String contentType;
  int requests = 0;

  @override
  Future<Dio> create(Instance instance) async =>
      Dio(BaseOptions(baseUrl: 'http://adguard.test/'))
        ..httpClientAdapter = _Counting(this);
}

class _Counting implements HttpClientAdapter {
  _Counting(this._server);

  final _CountingDioFactory _server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _server.requests++;
    return ResponseBody.fromString(
      _server.body,
      _server.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[_server.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
