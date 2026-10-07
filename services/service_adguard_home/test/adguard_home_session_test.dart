import 'dart:async';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late AdguardHomeSession session;
  late Dio dio;

  setUp(() {
    server = FakeAdguardHome();
    session = AdguardHomeSession();
    dio = dioFor(server);
  });

  Future<Response<dynamic>> ask(String path) =>
      session.run(() => dio.get<dynamic>(path));

  /// The error [call] ends in, or null if it succeeds.
  Future<Object?> errorOf(Future<Object?> call) =>
      call.then<Object?>((Object? _) => null, onError: (Object e) => e);

  test('counts the refusals in a row, and an answer wipes the count',
      () async {
    expect(session.refusals, 0);
    server.refusing = true;

    await errorOf(ask('control/status'));
    expect(session.refusals, 1);

    // Held back by the latch: never sent, so the server never counted it.
    await errorOf(ask('control/stats'));
    expect(session.refusals, 1);

    session.retry();
    await errorOf(ask('control/status'));
    expect(session.refusals, 2);

    server.refusing = false;
    session.retry();
    await ask('control/status');
    expect(session.refusals, 0);
  });

  test('a failure that is not a refusal leaves the count as it was',
      () async {
    server.refusing = true;
    await errorOf(ask('control/status'));
    server.refusing = false;
    session.retry();
    server.fail('GET', 'control/status', 502, 'bad gateway');

    await errorOf(ask('control/status'));

    // Nothing was learned about the sign-in either way.
    expect(session.refusals, 1);
  });

  test('lets one request out at a time', () async {
    server.hold = Completer<void>();
    final Future<Response<dynamic>> first = ask('control/status');
    final Future<Response<dynamic>> second = ask('control/stats');
    // Wait for the first to reach the server, then give the second every
    // chance to follow it.
    while (server.requests.isEmpty) {
      await pumpEventQueue(times: 1);
    }
    await pumpEventQueue();

    // The second has not left while the first is still out.
    expect(server.requests, hasLength(1));

    server.hold!.complete();
    await first;
    await second;
    expect(
      server.requests.map((RequestOptions r) => r.path),
      <String>['control/status', 'control/stats'],
    );
  });

  test('a refused sign-in reaches the server once, whatever is waiting',
      () async {
    // Opening the Home tab asks four things at once. Five wrong sign-ins
    // lock the address out for fifteen minutes.
    server.refusing = true;

    final List<Object?> errors = await Future.wait(<Future<Object?>>[
      errorOf(ask('control/status')),
      errorOf(ask('control/stats')),
      errorOf(ask('control/filtering/status')),
      errorOf(ask('control/stats/config')),
    ]);

    expect(errors, everyElement(isA<AdguardHomeSignInRefused>()));
    expect(server.requests, hasLength(1));
    expect(session.refused, isTrue);
  });

  test('nothing more is sent until the user tries again', () async {
    server.refusing = true;
    expect(await errorOf(ask('control/status')), isA<AdguardHomeSignInRefused>());
    expect(await errorOf(ask('control/status')), isA<AdguardHomeSignInRefused>());
    expect(await errorOf(ask('control/stats')), isA<AdguardHomeSignInRefused>());
    expect(server.requests, hasLength(1));

    // Trying again costs exactly one request.
    session.retry();
    expect(await errorOf(ask('control/status')), isA<AdguardHomeSignInRefused>());
    expect(await errorOf(ask('control/stats')), isA<AdguardHomeSignInRefused>());
    expect(server.requests, hasLength(2));

    // Once the password is right, everything flows again.
    server.refusing = false;
    session.retry();
    expect((await ask('control/status')).statusCode, 200);
    expect((await ask('control/stats')).statusCode, 200);
    expect(session.refused, isFalse);
  });

  test('a failure that is not a refused sign-in stops nothing', () async {
    server.fail('GET', 'control/status', 500, 'boom');

    expect(await errorOf(ask('control/status')), isA<NetworkException>());
    expect(session.refused, isFalse);
    expect((await ask('control/stats')).statusCode, 200);
  });

  test('the reason the server gives for turning a request down is kept',
      () async {
    server.fail(
      'POST',
      'control/protection',
      400,
      'reading req: json: cannot unmarshal string into Go struct field '
          'protectionJSON.enabled of type bool',
    );

    final Object? error = await errorOf(
      session.run(
        () => dio.post<dynamic>(
          'control/protection',
          data: <String, dynamic>{'enabled': 'yes'},
        ),
      ),
    );

    expect(
      error,
      isA<AdguardHomeRequestRefused>().having(
        (AdguardHomeRequestRefused e) => e.message,
        'message',
        'reading req: json: cannot unmarshal string into Go struct field '
            'protectionJSON.enabled of type bool',
      ),
    );
  });

  test('a web page is not taken for the server giving a reason', () async {
    // Some other server on that address, or a proxy's error page.
    server.fail(
      'GET',
      'control/status',
      404,
      '<html><body>Not found</body></html>',
      contentType: 'text/html',
    );

    expect(await errorOf(ask('control/status')), isA<NetworkException>());
  });

  test('an error thrown while reading an answer is passed on as it is',
      () async {
    final Object? error = await errorOf(
      session.run<Object?>(() async => throw const FormatException('odd')),
    );

    expect(error, isA<FormatException>());
    // And the queue is not left stuck behind it.
    expect((await ask('control/status')).statusCode, 200);
  });
}
