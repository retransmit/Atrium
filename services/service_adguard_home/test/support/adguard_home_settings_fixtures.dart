/// What AdGuard Home v0.107.79 answered about its settings, captured from
/// a real server on 2026-10-20, unless a comment says a fixture is made up.
/// The query log and statistics configs are in the older fixture files.
/// Keep them as the server sent them: tests that need something else build
/// on a copy.
library;

/// `GET control/dns_info`.
Map<String, dynamic> dnsInfoJson() => <String, dynamic>{
      'upstream_dns': <dynamic>[
        'https://dns10.quad9.net/dns-query',
      ],
      'upstream_dns_file': '',
      'bootstrap_dns': <dynamic>[
        '9.9.9.10',
        '149.112.112.10',
        '2620:fe::10',
        '2620:fe::fe:10',
      ],
      'fallback_dns': <dynamic>[],
      'protection_enabled': true,
      'ratelimit': 20,
      'ratelimit_subnet_len_ipv4': 24,
      'ratelimit_subnet_len_ipv6': 56,
      'upstream_timeout': 10,
      'ratelimit_whitelist': <dynamic>[],
      'blocking_mode': 'default',
      'edns_cs_enabled': false,
      'edns_cs_use_custom': false,
      'dnssec_enabled': true,
      'disable_ipv6': false,
      'upstream_mode': '',
      'blocked_response_ttl': 10,
      'cache_size': 4194304,
      'cache_ttl_min': 0,
      'cache_ttl_max': 0,
      'cache_enabled': true,
      'cache_optimistic': false,
      'resolve_clients': true,
      'use_private_ptr_resolvers': true,
      'local_ptr_upstreams': <dynamic>[],
      'blocking_ipv4': '',
      'blocking_ipv6': '',
      'protection_disabled_until': null,
      'edns_cs_custom_ip': '',
      'default_local_ptr_upstreams': <dynamic>[
        '192.168.65.7:53',
      ],
      };

/// `GET control/dhcp/status` of a server not serving DHCP.
Map<String, dynamic> dhcpOffJson() => <String, dynamic>{
      'interface_name': '',
      'v4': <String, dynamic>{
        'gateway_ip': '',
        'subnet_mask': '',
        'range_start': '',
        'range_end': '',
        'lease_duration': 0,
      },
      'v6': <String, dynamic>{
        'range_start': '',
        'lease_duration': 86400,
      },
      'leases': <dynamic>[],
      'static_leases': <dynamic>[],
      'enabled': false,
      };

/// `GET control/tls/status` of a server without encryption. The real answer
/// carries the certificate and key text, empty here.
Map<String, dynamic> tlsOffJson() => <String, dynamic>{
      'not_before': '0001-01-01T00:00:00Z',
      'not_after': '0001-01-01T00:00:00Z',
      'dns_names': null,
      'valid_cert': false,
      'valid_chain': false,
      'valid_key': false,
      'valid_pair': false,
      'enabled': false,
      'force_https': false,
      'port_https': 443,
      'port_dns_over_tls': 853,
      'port_dns_over_quic': 853,
      'port_dnscrypt': 0,
      'dnscrypt_config_file': '',
      'certificate_chain': '',
      'private_key': '',
      'certificate_path': '',
      'private_key_path': '',
      'private_key_saved': false,
      'serve_plain_dns': true,
      };

/// `GET control/tls/status` of a server with encryption on. Made up, in the
/// shape of the captured one: the test server has no certificate. The
/// certificate and key text are there to prove they are never read.
Map<String, dynamic> tlsOnJson() => <String, dynamic>{
      ...tlsOffJson(),
      'enabled': true,
      'server_name': 'dns.home.example',
      'force_https': true,
      'port_https': 443,
      'port_dns_over_tls': 853,
      'port_dns_over_quic': 853,
      'port_dnscrypt': 0,
      'certificate_chain': 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t',
      'private_key': 'LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t',
      'valid_cert': true,
      'valid_chain': true,
      'valid_key': true,
      'valid_pair': true,
      'key_type': 'ECDSA',
      'issuer': "CN=R11,O=Let's Encrypt,C=US",
      'subject': 'CN=dns.home.example',
      'not_before': '2026-09-01T00:00:00Z',
      'not_after': '2026-11-30T00:00:00Z',
      'dns_names': <dynamic>['dns.home.example'],
      'warning_validation': '',
    };

/// `GET control/dhcp/status` of a server handing out addresses. Made up:
/// the test container cannot serve DHCP.
Map<String, dynamic> dhcpOnJson() => <String, dynamic>{
      'enabled': true,
      'interface_name': 'eth0',
      'v4': <String, dynamic>{
        'gateway_ip': '192.168.1.1',
        'subnet_mask': '255.255.255.0',
        'range_start': '192.168.1.100',
        'range_end': '192.168.1.200',
        'lease_duration': 86400,
      },
      'v6': <String, dynamic>{
        'range_start': '',
        'lease_duration': 86400,
      },
      'leases': <dynamic>[
        <String, dynamic>{
          'mac': 'aa:bb:cc:dd:ee:10',
          'ip': '192.168.1.110',
          'hostname': 'kitchen-speaker',
          'expires': '2026-10-21T08:30:00Z',
        },
      ],
      'static_leases': <dynamic>[
        <String, dynamic>{
          'mac': 'aa:bb:cc:dd:ee:20',
          'ip': '192.168.1.20',
          'hostname': 'nas',
        },
      ],
    };

/// `POST control/version.json`: what the test server says, its update
/// check being off.
Map<String, dynamic> versionDisabledJson() => <String, dynamic>{
      'disabled': true,
    };

/// `POST control/version.json` with a newer version out. Made up, in the
/// shape the web UI reads.
Map<String, dynamic> versionNewJson() => <String, dynamic>{
      'new_version': 'v0.107.80',
      'announcement': 'AdGuard Home v0.107.80 is now available!',
      'announcement_url':
          'https://github.com/AdguardTeam/AdGuardHome/releases/tag/v0.107.80',
      'can_autoupdate': true,
    };

/// `POST control/test_upstream_dns`, captured: one server that answered and
/// one that did not.
Map<String, dynamic> testUpstreamJson() => <String, dynamic>{
      'https://dns10.quad9.net:443/dns-query': 'OK',
      '10.255.255.1:53': "couldn't communicate with upstream: exchanging with "
          '10.255.255.1:53 over udp: i/o timeout',
    };
