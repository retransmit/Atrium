import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

void main() {
  group('Gluetun Models JSON parsing', () {
    test('GluetunVpnStatus parses correctly', () {
      final status = GluetunVpnStatus.fromJson({'status': 'running'});
      expect(status.status, 'running');
      expect(status.isRunning, isTrue);
      expect(status.isStopped, isFalse);

      final stopped = GluetunVpnStatus.fromJson({'status': 'stopped'});
      expect(stopped.isRunning, isFalse);
      expect(stopped.isStopped, isTrue);
    });

    test('GluetunPublicIp parses correctly', () {
      final ip = GluetunPublicIp.fromJson({
        'public_ip': '203.0.113.45',
        'country': 'Switzerland',
        'region': 'Zurich',
        'city': 'Zurich',
        'organization': 'Mullvad',
      });
      expect(ip.publicIp, '203.0.113.45');
      expect(ip.country, 'Switzerland');
      expect(ip.region, 'Zurich');
      expect(ip.city, 'Zurich');
      expect(ip.organization, 'Mullvad');
    });

    test('GluetunPortForward parses integer and string port', () {
      final pfInt = GluetunPortForward.fromJson({
        'port': 12345,
        'status': 'forwarded',
      });
      expect(pfInt.port, 12345);
      expect(pfInt.status, 'forwarded');

      final pfStr = GluetunPortForward.fromJson({'port': '54321'});
      expect(pfStr.port, 54321);
    });

    test('GluetunDnsStatus parses correctly', () {
      final dns = GluetunDnsStatus.fromJson({'status': 'running'});
      expect(dns.status, 'running');
      expect(dns.isRunning, isTrue);
    });
  });
}
