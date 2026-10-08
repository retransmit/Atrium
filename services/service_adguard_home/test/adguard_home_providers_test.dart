import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late ProviderContainer container;

  /// The same server after its password was corrected in Atrium. Editing an
  /// instance makes a different [Instance].
  final Instance corrected = adguardHomeTestInstance.copyWith(
    auth: const InstanceAuth.userPass(username: 'admin', password: 'right'),
  );

  setUp(() {
    server = FakeAdguardHome();
    container = ProviderContainer(
      overrides: <Override>[
        for (final Instance instance in <Instance>[
          adguardHomeTestInstance,
          corrected,
        ])
          instanceDioProvider(instance)
              .overrideWith((Ref ref) async => dioFor(server)),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Keeps an auto-disposed provider alive for the length of the test and
  /// waits for its first value or error.
  ///
  /// An error counts the moment it is there. Riverpod retries a failed
  /// provider by itself for a while and reports it as loading meanwhile, so
  /// waiting for the loading to end would wait out every retry.
  Future<Object?> settle<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final Completer<Object?> done = Completer<Object?>();
    container.listen<AsyncValue<T>>(
      provider,
      (AsyncValue<T>? _, AsyncValue<T> next) {
        if (done.isCompleted) return;
        if (next.hasError) {
          done.complete(next.error);
        } else if (!next.isLoading) {
          done.complete(next.value);
        }
      },
      fireImmediately: true,
    );
    return done.future;
  }

  /// Lets pending work run until [condition] holds.
  Future<void> until(bool Function() condition) async {
    for (int turn = 0; turn < 500 && !condition(); turn++) {
      await pumpEventQueue(times: 1);
    }
    expect(condition(), isTrue, reason: 'the awaited state never came');
  }

  AdguardHomeActions actions() =>
      container.read(adguardHomeActionsProvider(adguardHomeTestInstance));

  test('reads the status, the statistics, the lists and the period', () async {
    expect(
      await settle(adguardHomeStatusProvider(adguardHomeTestInstance)),
      isA<AdguardHomeStatus>()
          .having((AdguardHomeStatus s) => s.version, 'version', 'v0.107.79'),
    );
    expect(
      await settle(adguardHomeStatsProvider(adguardHomeTestInstance)),
      isA<AdguardHomeStats>()
          .having((AdguardHomeStats s) => s.queries, 'queries', 68),
    );
    expect(
      await settle(adguardHomeFilteringProvider(adguardHomeTestInstance)),
      isA<AdguardHomeFiltering>(),
    );
    expect(
      await settle(adguardHomeStatsPeriodProvider(adguardHomeTestInstance)),
      const Duration(hours: 24),
    );
  });

  test('a wrong password reaches the server once across every provider',
      () async {
    server.refusing = true;

    final List<Object?> results = await Future.wait(<Future<Object?>>[
      settle(adguardHomeStatusProvider(adguardHomeTestInstance)),
      settle(adguardHomeStatsProvider(adguardHomeTestInstance)),
      settle(adguardHomeFilteringProvider(adguardHomeTestInstance)),
      settle(adguardHomeStatsPeriodProvider(adguardHomeTestInstance)),
    ]);

    expect(results, everyElement(isA<AdguardHomeSignInRefused>()));
    expect(server.requests, hasLength(1));
  });

  test('trying again costs one request, and works once the password is right',
      () async {
    server.refusing = true;
    await settle(adguardHomeStatusProvider(adguardHomeTestInstance));
    await settle(adguardHomeStatsProvider(adguardHomeTestInstance));
    expect(server.requests, hasLength(1));

    // Both are read again, and still only one request leaves.
    actions().retrySignIn();
    await until(() => server.requests.length == 2);
    await pumpEventQueue();
    expect(server.requests, hasLength(2));

    server.refusing = false;
    actions().retrySignIn();
    await until(
      () =>
          container
              .read(adguardHomeStatusProvider(adguardHomeTestInstance))
              .hasValue &&
          container
              .read(adguardHomeStatsProvider(adguardHomeTestInstance))
              .hasValue,
    );
    expect(
      container.read(adguardHomeStatusProvider(adguardHomeTestInstance)).value,
      isA<AdguardHomeStatus>(),
    );
    expect(
      container.read(adguardHomeStatsProvider(adguardHomeTestInstance)).value,
      isA<AdguardHomeStats>(),
    );
  });

  testWidgets('no timer sends a refused sign-in again',
      (WidgetTester tester) async {
    // Riverpod retries a failed provider by itself, ten times over about
    // forty seconds, and the poll comes round again after that. Every one
    // of those has to stop at the session. This runs as a widget test only
    // for its clock, which can be moved forward.
    final FakeAdguardHome refusing = FakeAdguardHome()..refusing = true;
    final ProviderContainer timed = ProviderContainer(
      overrides: <Override>[
        instanceDioProvider(adguardHomeTestInstance)
            .overrideWith((Ref ref) async => dioFor(refusing)),
      ],
    );
    try {
      for (final ProviderListenable<Object?> provider
          in <ProviderListenable<Object?>>[
        adguardHomeStatusProvider(adguardHomeTestInstance),
        adguardHomeStatsProvider(adguardHomeTestInstance),
        adguardHomeFilteringProvider(adguardHomeTestInstance),
        adguardHomeStatsPeriodProvider(adguardHomeTestInstance),
      ]) {
        timed.listen<Object?>(provider, (Object? _, Object? __) {});
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(refusing.requests, hasLength(1));

      // Two minutes: past every retry, and past the status poll's backoff
      // twice over.
      for (int second = 0; second < 120; second++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(refusing.requests, hasLength(1));
      expect(
        timed.read(adguardHomeSessionProvider(adguardHomeTestInstance)).refused,
        isTrue,
      );
    } finally {
      // Before the test ends, not in a tear-down: the polls' timers must be
      // gone by the time the test checks that none is left.
      timed.dispose();
    }
  });

  test('an edited instance is not held back by the old refusal', () async {
    server.refusing = true;
    expect(
      await settle(adguardHomeStatusProvider(adguardHomeTestInstance)),
      isA<AdguardHomeSignInRefused>(),
    );

    // The corrected instance has a session of its own, so it is asked.
    server.refusing = false;
    expect(
      await settle(adguardHomeStatusProvider(corrected)),
      isA<AdguardHomeStatus>(),
    );
    // The old one stays shut until someone asks for it again.
    expect(
      container
          .read(adguardHomeSessionProvider(adguardHomeTestInstance))
          .refused,
      isTrue,
    );
  });

  test('pausing sends the length and reads the status again', () async {
    await settle(adguardHomeStatusProvider(adguardHomeTestInstance));
    expect(server.to('GET', 'control/status'), hasLength(1));

    await actions().setProtection(
      enabled: false,
      pause: const Duration(minutes: 10),
    );
    await until(() => server.to('GET', 'control/status').length == 2);

    expect(
      server.single('POST', 'control/protection').data,
      <String, dynamic>{'enabled': false, 'duration': 600000},
    );
    expect(server.to('GET', 'control/status'), hasLength(2));
  });

  test('blocking a domain writes the rule after reading the rules afresh',
      () async {
    server.on(
      'GET',
      'control/filtering/status',
      <String, dynamic>{
        'filters': null,
        'whitelist_filters': null,
        'user_rules': <dynamic>['||kept.example^'],
        'interval': 24,
        'enabled': true,
      },
    );

    final AdguardHomeRuleEdit edit =
        await actions().toggleBlocking('ads.example', block: true);

    expect(edit.change, AdguardHomeRuleChange.added);
    expect(
      server.single('POST', 'control/filtering/set_rules').data,
      <String, dynamic>{
        'rules': <String>['||kept.example^', r'||ads.example^$important'],
      },
    );
  });

  test('a rule that is already there is not written again', () async {
    server.on(
      'GET',
      'control/filtering/status',
      <String, dynamic>{
        'user_rules': <dynamic>[r'||ads.example^$important'],
      },
    );

    final AdguardHomeRuleEdit edit =
        await actions().toggleBlocking('ads.example', block: true);

    expect(edit.change, AdguardHomeRuleChange.alreadyThere);
    expect(server.to('POST', 'control/filtering/set_rules'), isEmpty);
  });

  test('tells an instance with a sign-in from one without', () {
    Instance withAuth(String username, String password) =>
        adguardHomeTestInstance.copyWith(
          auth: InstanceAuth.userPass(username: username, password: password),
        );

    expect(adguardHomeHasCredentials(adguardHomeTestInstance), isTrue);
    expect(adguardHomeHasCredentials(withAuth('', '')), isFalse);
    // Either half alone is still sent, so it counts.
    expect(adguardHomeHasCredentials(withAuth('admin', '')), isTrue);
    expect(adguardHomeHasCredentials(withAuth('', 'secret')), isTrue);
  });

  test('the pauses are the five the web UI offers, in its order', () {
    expect(
      adguardHomePauses.map((AdguardHomePause p) => p.label),
      <String>[
        '30 seconds',
        '1 minute',
        '10 minutes',
        '1 hour',
        'Until tomorrow',
      ],
    );
    // "Until tomorrow" is the flat 24 hours the web UI sends for it.
    expect(adguardHomePauses.last.length, const Duration(hours: 24));
    expect(adguardHomePauses.first.length, const Duration(seconds: 30));
  });
}
