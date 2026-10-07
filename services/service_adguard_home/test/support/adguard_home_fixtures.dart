/// What AdGuard Home v0.107.79 answered, captured from a real server on
/// 2026-10-07. Keep these as the server sent them: tests that need
/// something else build on a copy.
library;

/// `GET control/status`.
Map<String, dynamic> statusJson() => <String, dynamic>{
      'version': 'v0.107.79',
      'language': '',
      'dns_addresses': <dynamic>['127.0.0.1', '::1', '172.17.0.4'],
      'dns_port': 53,
      'http_port': 80,
      'protection_disabled_duration': 0,
      'start_time': 1791383832143.1316,
      'protection_enabled': true,
      'dhcp_available': true,
      'running': true,
    };

/// `GET control/stats`, after 68 queries of which 24 were blocked.
Map<String, dynamic> statsJson() => <String, dynamic>{
      'time_units': 'hours',
      'top_queried_domains': <dynamic>[
        <String, dynamic>{'github.com': 8},
        <String, dynamic>{'flutter.dev': 8},
        <String, dynamic>{'ads.google.com': 8},
        <String, dynamic>{'wikipedia.org': 8},
        <String, dynamic>{'example.com': 8},
        <String, dynamic>{'f-droid.org': 2},
        <String, dynamic>{'sonarr.tv': 2},
      ],
      'top_clients': <dynamic>[
        <String, dynamic>{'127.0.0.1': 68},
      ],
      'top_blocked_domains': <dynamic>[
        <String, dynamic>{'adservice.google.com': 8},
        <String, dynamic>{'doubleclick.net': 8},
        <String, dynamic>{'google-analytics.com': 8},
      ],
      'top_upstreams_responses': <dynamic>[
        <String, dynamic>{'https://dns10.quad9.net:443/dns-query': 24},
      ],
      'top_upstreams_avg_time': <dynamic>[
        <String, dynamic>{
          'https://dns10.quad9.net:443/dns-query': 0.18939004166666665,
        },
      ],
      'dns_queries': <dynamic>[
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 68,
      ],
      'blocked_filtering': <dynamic>[
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24,
      ],
      'replaced_safebrowsing': <dynamic>[
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ],
      'replaced_parental': <dynamic>[
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ],
      'num_dns_queries': 68,
      'num_blocked_filtering': 24,
      'num_replaced_safebrowsing': 0,
      'num_replaced_safesearch': 0,
      'num_replaced_parental': 0,
      'avg_processing_time': 0.067046,
    };

/// `GET control/filtering/status` on a fresh install: one list on, one off
/// and never fetched, no allowlists (sent as null), no custom rules.
Map<String, dynamic> filteringJson() => <String, dynamic>{
      'filters': <dynamic>[
        <String, dynamic>{
          'url':
              'https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt',
          'name': 'AdGuard DNS filter',
          'last_updated': '2026-10-07T14:27:02Z',
          'id': 1,
          'rules_count': 179185,
          'enabled': true,
        },
        <String, dynamic>{
          'url':
              'https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt',
          'name': 'AdAway Default Blocklist',
          'id': 2,
          'rules_count': 0,
          'enabled': false,
        },
      ],
      'whitelist_filters': null,
      'user_rules': <dynamic>[],
      'interval': 24,
      'enabled': true,
    };

/// `GET control/stats/config`. The interval is in milliseconds.
Map<String, dynamic> statsConfigJson() => <String, dynamic>{
      'ignored': <dynamic>[],
      'interval': 86400000,
      'enabled': true,
      'ignored_enabled': false,
    };
