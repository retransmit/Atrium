import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_technitium/service_technitium.dart';

import 'support/technitium_test_instance.dart';

class _FakeApi extends TechnitiumApi {
  _FakeApi() : super(Dio());

  bool setBlockingCalled = false;
  final List<bool> setBlockingHistory = <bool>[];
  num? tempDisableMinutes;
  bool flushCacheCalled = false;
  bool forceUpdateCalled = false;
  String? addedDomain;
  String? deletedDomain;
  Completer<void>? statusGate;

  @override
  Future<TechnitiumStatus> getStatus() async {
    final Completer<void>? gate = statusGate;
    if (gate != null) await gate.future;
    return TechnitiumStatus(
      version: '13.0.0',
      isBlockingEnabled: true,
      readAt: DateTime.now(),
    );
  }

  @override
  Future<TechnitiumSettings> getSettings() async {
    return const TechnitiumSettings();
  }

  @override
  Future<TechnitiumStats> getStats({String type = 'LastDay'}) async {
    return const TechnitiumStats(totalQueries: 100, blockedQueries: 10);
  }

  @override
  Future<List<TechnitiumBlockedZone>> listBlockedZones() async {
    return const <TechnitiumBlockedZone>[
      TechnitiumBlockedZone(domain: 'bad.com'),
    ];
  }

  @override
  Future<void> setBlocking({required bool enabled}) async {
    setBlockingCalled = true;
    setBlockingHistory.add(enabled);
  }

  @override
  Future<void> temporaryDisableBlocking({required num minutes}) async {
    tempDisableMinutes = minutes;
  }

  @override
  Future<void> flushDnsCache() async {
    flushCacheCalled = true;
  }

  @override
  Future<void> forceUpdateBlockLists() async {
    forceUpdateCalled = true;
  }

  @override
  Future<void> addBlockedZone(String domain) async {
    addedDomain = domain;
  }

  @override
  Future<void> deleteBlockedZone(String domain) async {
    deletedDomain = domain;
  }
}

void main() {
  group('Technitium Providers and Actions', () {
    test('Actions trigger mutations and invalidate state', () async {
      final _FakeApi fakeApi = _FakeApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          technitiumApiProvider(technitiumTestInstance)
              .overrideWith((_) async => fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final TechnitiumActions actions =
          container.read(technitiumActionsProvider(technitiumTestInstance));

      // Test pause
      await actions.setProtection(
        enabled: false,
        pause: const Duration(minutes: 10),
      );
      expect(fakeApi.tempDisableMinutes, 10.0);

      // Test disable (clears pending pause via enable=true before disable)
      await actions.setProtection(enabled: false);
      expect(fakeApi.setBlockingHistory, <bool>[true, false]);

      // Test resume (enable=true disposes pause timer directly)
      fakeApi.setBlockingCalled = false;
      fakeApi.setBlockingHistory.clear();
      await actions.setProtection(enabled: true);
      expect(fakeApi.setBlockingHistory, <bool>[true]);
      expect(fakeApi.setBlockingCalled, isTrue);

      // Test flush cache
      await actions.flushDnsCache();
      expect(fakeApi.flushCacheCalled, isTrue);

      // Test force update block lists
      await actions.forceUpdateBlockLists();
      expect(fakeApi.forceUpdateCalled, isTrue);

      // Test add and delete zone
      await actions.addBlockedZone('ad.tracker.com');
      expect(fakeApi.addedDomain, 'ad.tracker.com');

      await actions.deleteBlockedZone('ad.tracker.com');
      expect(fakeApi.deletedDomain, 'ad.tracker.com');
    });

    test('refreshOverview waits for provider reloads', () async {
      final _FakeApi fakeApi = _FakeApi()..statusGate = Completer<void>();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          technitiumApiProvider(technitiumTestInstance)
              .overrideWith((_) async => fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final TechnitiumActions actions =
          container.read(technitiumActionsProvider(technitiumTestInstance));

      bool completed = false;
      final Future<void> refresh =
          actions.refreshOverview().whenComplete(() => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      fakeApi.statusGate!.complete();
      await refresh;
      expect(completed, isTrue);
    });

    test('Period and query log filters update cleanly', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(technitiumStatsPeriodProvider(technitiumTestInstance)),
        'LastDay',
      );

      container
          .read(technitiumStatsPeriodProvider(technitiumTestInstance).notifier)
          .state = 'LastWeek';
      expect(
        container.read(technitiumStatsPeriodProvider(technitiumTestInstance)),
        'LastWeek',
      );

      expect(
        container
            .read(technitiumQueryLogFilterProvider(technitiumTestInstance)),
        'All',
      );
      container
          .read(
            technitiumQueryLogFilterProvider(technitiumTestInstance).notifier,
          )
          .state = 'Blocked';
      expect(
        container
            .read(technitiumQueryLogFilterProvider(technitiumTestInstance)),
        'Blocked',
      );
    });
  });
}
