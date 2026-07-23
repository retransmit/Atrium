import 'package:flutter_test/flutter_test.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

import 'fixtures/speedtest_responses.dart';

void main() {
  group('SpeedtestResult', () {
    test('parses current payload and optional nested measurements', () {
      final SpeedtestResult result = SpeedtestResult.fromJson(currentResult);

      expect(result.id, 42);
      expect(result.status, SpeedtestResultStatus.completed);
      expect(result.downloadBitsPerSecond, 800000000);
      expect(result.uploadBitsPerSecond, 200000000);
      expect(result.pingMilliseconds, 12.4);
      expect(result.jitterMilliseconds, 1.8);
      expect(result.packetLossPercent, 0.5);
      expect(result.healthy, isTrue);
      expect(result.server?.displayName, 'Example Speedtest');
      expect(result.server?.displayLocation, 'Seattle, WA, United States');
      expect(result.isp, 'Example Fiber');
      expect(result.completedAt, DateTime.parse('2026-07-20T18:15:00Z'));
    });

    test('supports legacy byte-per-second values and missing optionals', () {
      final SpeedtestResult result = SpeedtestResult.fromJson(legacyResult);

      expect(result.downloadBitsPerSecond, 100000000);
      expect(result.uploadBitsPerSecond, 50000000);
      expect(result.jitterMilliseconds, isNull);
      expect(result.packetLossPercent, isNull);
      expect(result.server, isNull);
      expect(result.isp, isNull);
      expect(result.completedAt, DateTime(2024, 1, 2, 3, 4, 5));
    });

    test('rejects a result without required identity', () {
      expect(
        () =>
            SpeedtestResult.fromJson(<String, dynamic>{'status': 'completed'}),
        throwsA(isA<SpeedtestProtocolException>()),
      );
    });

    test('unknown statuses remain explicit and terminal', () {
      final SpeedtestResult result = SpeedtestResult.fromJson(
        <String, dynamic>{'id': 1, 'status': 'future-status'},
      );
      expect(result.status, SpeedtestResultStatus.unknown);
      expect(result.status.isInProgress, isFalse);
    });

    test('omits negative and non-finite off-contract measurements', () {
      final SpeedtestResult result = SpeedtestResult.fromJson(
        <String, dynamic>{
          'id': 2,
          'status': 'completed',
          'download_bits': double.nan,
          'upload_bits': double.infinity,
          'ping': -1,
          'data': <String, dynamic>{'packetLoss': -5},
        },
      );

      expect(result.downloadBitsPerSecond, isNull);
      expect(result.uploadBitsPerSecond, isNull);
      expect(result.pingMilliseconds, isNull);
      expect(result.packetLossPercent, isNull);
    });
  });

  group('SpeedtestResultsPage', () {
    test('parses pagination without trusting the absolute next URL', () {
      final SpeedtestResultsPage page = SpeedtestResultsPage.fromJson(
        resultPage(<Map<String, dynamic>>[currentResult], lastPage: 2),
        requestedPage: 1,
        pageSize: 25,
      );
      expect(page.results, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.page, 1);
    });

    test('accepts an empty history', () {
      final SpeedtestResultsPage page = SpeedtestResultsPage.fromJson(
        resultPage(const <Map<String, dynamic>>[]),
        requestedPage: 1,
        pageSize: 25,
      );
      expect(page.results, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  test('formats speed, latency, and packet loss units', () {
    expect(formatSpeed(999000000), '999 Mbps');
    expect(formatSpeed(1250000000), '1.25 Gbps');
    expect(formatMilliseconds(12.45), '12.4 ms');
    expect(formatPacketLoss(0.25), '0.3%');
  });
}
