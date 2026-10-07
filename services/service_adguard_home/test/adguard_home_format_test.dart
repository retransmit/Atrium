import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

void main() {
  test('counts are written out in full, compact ones for small spaces', () {
    expect(formatAdguardHomeCount(0), '0');
    expect(formatAdguardHomeCount(5690), '5,690');
    expect(formatAdguardHomeCount(724480), '724,480');
    expect(formatAdguardHomeCompact(740), '740');
    expect(formatAdguardHomeCompact(5690), '5.69K');
    expect(formatAdguardHomeCompact(724480), '724K');
  });

  test('a share is written to two places with no trailing zeros', () {
    expect(formatAdguardHomePercent(0), '0%');
    expect(formatAdguardHomePercent(13.0123), '13.01%');
    expect(formatAdguardHomePercent(35.294117), '35.29%');
    expect(formatAdguardHomePercent(50), '50%');
    expect(formatAdguardHomePercent(13.1), '13.1%');
    expect(formatAdguardHomePercent(100), '100%');
  });

  test('a share for a small space is whole, or has one decimal below ten',
      () {
    expect(formatAdguardHomeCompactPercent(0), '0%');
    expect(formatAdguardHomeCompactPercent(0.42), '0.4%');
    expect(formatAdguardHomeCompactPercent(4), '4%');
    expect(formatAdguardHomeCompactPercent(9.86), '9.9%');
    // Would round to 10.0, which is as wide as the space allows nothing of.
    expect(formatAdguardHomeCompactPercent(9.96), '10%');
    expect(formatAdguardHomeCompactPercent(13.0123), '13%');
    expect(formatAdguardHomeCompactPercent(36.5), '37%');
    expect(formatAdguardHomeCompactPercent(100), '100%');
  });

  test('how long an answer took is written the way the web UI writes it',
      () {
    // Under a millisecond with two decimals, from one up whole and rounded
    // down.
    expect(
      formatAdguardHomeElapsed(const Duration(microseconds: 124)),
      '0.12 ms',
    );
    expect(
      formatAdguardHomeElapsed(const Duration(microseconds: 44)),
      '0.04 ms',
    );
    expect(formatAdguardHomeElapsed(Duration.zero), '0.00 ms');
    expect(formatAdguardHomeElapsed(const Duration(milliseconds: 1)), '1 ms');
    expect(
      formatAdguardHomeElapsed(const Duration(microseconds: 28702)),
      '28 ms',
    );
    expect(
      formatAdguardHomeElapsed(const Duration(microseconds: 365871)),
      '365 ms',
    );
    // Grouped like every other figure of the service.
    expect(formatAdguardHomeElapsed(const Duration(seconds: 2)), '2,000 ms');
    expect(formatAdguardHomeElapsed(null), '');
  });

  group('when a query came in', () {
    // The server sends UTC. These are built in local time and turned into
    // UTC, so the test reads the same in every time zone.
    final DateTime now = DateTime(2026, 10, 7, 23);

    test('today is a time of day', () {
      final DateTime time = DateTime(2026, 10, 7, 20, 29, 32).toUtc();

      expect(formatAdguardHomeLogTime(time, now), '20:29:32');
    });

    test('another day has its date in front', () {
      final DateTime time = DateTime(2026, 10, 5, 9, 4, 7).toUtc();

      expect(formatAdguardHomeLogTime(time, now), '5 Oct 09:04:07');
    });

    test('another year has that too', () {
      final DateTime time = DateTime(2025, 12, 31, 23, 59, 59).toUtc();

      expect(formatAdguardHomeLogTime(time, now), '31 Dec 2025 23:59:59');
    });

    test('a time the server did not send reads as nothing', () {
      expect(formatAdguardHomeLogTime(null, now), '');
      expect(formatAdguardHomeLogMoment(null), '');
    });

    test('in full it has the date and the milliseconds', () {
      final DateTime time = DateTime(2026, 10, 7, 20, 29, 32, 377).toUtc();

      expect(formatAdguardHomeLogMoment(time), '7 Oct 2026, 20:29:32.377');
    });
  });

  test('names the way a query arrived as the web UI does', () {
    expect(adguardHomeProtocolLabel(''), 'Plain DNS');
    expect(adguardHomeProtocolLabel('doh'), 'DNS-over-HTTPS');
    expect(adguardHomeProtocolLabel('dot'), 'DNS-over-TLS');
    expect(adguardHomeProtocolLabel('doq'), 'DNS-over-QUIC');
    expect(adguardHomeProtocolLabel('dnscrypt'), 'DNSCrypt');
    // One this app has not heard of is shown as sent.
    expect(adguardHomeProtocolLabel('carrier-pigeon'), 'carrier-pigeon');
  });

  test('processing time is in milliseconds', () {
    expect(
      formatAdguardHomeProcessingTime(const Duration(microseconds: 67046)),
      '67 ms',
    );
    expect(formatAdguardHomeProcessingTime(Duration.zero), '0 ms');
  });

  test('a countdown rounds up and never goes below zero', () {
    expect(formatAdguardHomeCountdown(const Duration(seconds: 30)), '0:30');
    // 29.7 s left is still "0:30" to someone watching it.
    expect(
      formatAdguardHomeCountdown(const Duration(milliseconds: 29700)),
      '0:30',
    );
    expect(
      formatAdguardHomeCountdown(const Duration(minutes: 9, seconds: 41)),
      '9:41',
    );
    expect(formatAdguardHomeCountdown(const Duration(hours: 1)), '1:00:00');
    expect(
      formatAdguardHomeCountdown(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      ),
      '23:59:59',
    );
    expect(formatAdguardHomeCountdown(Duration.zero), '0:00');
    expect(formatAdguardHomeCountdown(const Duration(seconds: -5)), '0:00');
  });

  test('the period is named the way the web UI names it', () {
    expect(adguardHomePeriodLabel(const Duration(hours: 24)), 'Last 24 hours');
    expect(adguardHomePeriodLabel(const Duration(days: 7)), 'Last 7 days');
    expect(adguardHomePeriodLabel(const Duration(days: 90)), 'Last 90 days');
    expect(adguardHomePeriodLabel(const Duration(hours: 6)), 'Last 6 hours');
    expect(adguardHomePeriodLabel(const Duration(hours: 1)), 'Last hour');
    expect(adguardHomePeriodLabel(const Duration(hours: 36)), 'Last 36 hours');
  });
}
