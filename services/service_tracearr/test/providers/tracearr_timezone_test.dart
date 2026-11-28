import 'package:core_models/core_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_tracearr/src/models/tracearr_models.dart';
import 'package:service_tracearr/src/providers/tracearr_providers.dart';
import 'package:service_tracearr/src/repository/tracearr_repository.dart';

/// Records the timezone each call was made with.
class _RecordingRepository implements TracearrRepository {
  final List<String?> todayZones = <String?>[];
  final List<String?> activityZones = <String?>[];

  @override
  Future<TracearrTodayStats> getStatsToday({
    String? serverId,
    String? timezone,
  }) async {
    todayZones.add(timezone);
    return const TracearrTodayStats();
  }

  @override
  Future<TracearrActivityTrend> getActivity({
    String? period = 'week',
    String? serverId,
    String? timezone,
  }) async {
    activityZones.add(timezone);
    return const TracearrActivityTrend(period: 'week');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Instance instance = Instance(
    id: 'inst_tz',
    name: 'Tracearr',
    kind: ServiceKind.tracearr,
    localUrl: 'https://tr.example.com',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuthApiKey(apiKey: 'dummy'),
  );

  void answerTimezone(Object? Function() answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timezoneChannel, (MethodCall call) async {
      return answer();
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timezoneChannel, null);
  });

  group('tracearrDeviceTimezoneProvider', () {
    test("reads the device's IANA timezone", () async {
      answerTimezone(() => 'America/Los_Angeles');
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(tracearrDeviceTimezoneProvider.future),
        'America/Los_Angeles',
      );
    });

    test('is null when the platform cannot say', () async {
      answerTimezone(() => throw PlatformException(code: 'unavailable'));
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(tracearrDeviceTimezoneProvider.future), isNull);
    });

    test('is null when the platform has no timezone plugin', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(tracearrDeviceTimezoneProvider.future), isNull);
    });

    test('is null for an empty answer', () async {
      answerTimezone(() => '');
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(tracearrDeviceTimezoneProvider.future), isNull);
    });
  });

  group('calendar queries use the device timezone', () {
    late _RecordingRepository repository;

    ProviderContainer containerWith(String? deviceZone) {
      repository = _RecordingRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          tracearrRepositoryProvider(instance)
              .overrideWith((ref) async => repository),
          tracearrDeviceTimezoneProvider.overrideWith((ref) async => deviceZone),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('the weekly activity is bucketed in it', () async {
      final ProviderContainer container = containerWith('America/Los_Angeles');
      await container
          .read(tracearrActivityProvider((instance, 'week', null, null)).future);
      expect(repository.activityZones, <String?>['America/Los_Angeles']);
    });

    test("today's stats count its today", () async {
      final ProviderContainer container = containerWith('Asia/Kolkata');
      await container
          .read(tracearrTodayStatsProvider((instance, null, null)).future);
      expect(repository.todayZones, <String?>['Asia/Kolkata']);
    });

    test('a timezone the caller names wins', () async {
      final ProviderContainer container = containerWith('America/Los_Angeles');
      await container.read(
        tracearrActivityProvider((instance, 'week', null, 'Europe/Berlin')).future,
      );
      await container
          .read(tracearrTodayStatsProvider((instance, null, 'Europe/Berlin')).future);
      expect(repository.activityZones, <String?>['Europe/Berlin']);
      expect(repository.todayZones, <String?>['Europe/Berlin']);
    });

    test("an unknown device timezone leaves Tracearr's default", () async {
      final ProviderContainer container = containerWith(null);
      await container
          .read(tracearrActivityProvider((instance, 'week', null, null)).future);
      await container
          .read(tracearrTodayStatsProvider((instance, null, null)).future);
      expect(repository.activityZones, <String?>[null]);
      expect(repository.todayZones, <String?>[null]);
    });
  });
}
