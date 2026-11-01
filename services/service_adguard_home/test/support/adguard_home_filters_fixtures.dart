/// What AdGuard Home v0.107.79 answered about its filters, captured from a
/// real server on 2026-10-19. Keep these as the server sent them: tests that
/// need something else build on a copy.
library;

/// `GET control/filtering/status`: two blocklists, the second switched off
/// (so it reports no rules), one allowlist, and the three custom rules.
Map<String, dynamic> filterStatusJson() => <String, dynamic>{
      'filters': <dynamic>[
        <String, dynamic>{
          'url': 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt',
          'name': 'AdGuard DNS filter',
          'last_updated': '2026-10-19T15:28:07Z',
          'id': 1,
          'rules_count': 186502,
          'enabled': true,
        },
        <String, dynamic>{
          'url': 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt',
          'name': 'AdAway Default Blocklist',
          'id': 2,
          'rules_count': 0,
          'enabled': false,
        },
      ],
      'whitelist_filters': <dynamic>[
        <String, dynamic>{
          'url': 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt',
          'name': 'Allow common services',
          'last_updated': '2026-10-19T15:30:06Z',
          'id': 1792423510,
          'rules_count': 3554,
          'enabled': true,
        },
      ],
      'user_rules': <dynamic>[
        '@@||wikipedia.org^',
        '||blocked-by-custom.example^',
        '|rule-rewrite.example^\$dnsrewrite=10.0.0.7',
      ],
      'interval': 24,
      'enabled': true,
    };

/// `GET control/blocked_services/get`: TikTok, with blocking paused on
/// Saturday from 9 to 17 and all of Sunday, Berlin time.
Map<String, dynamic> globalServicesJson() => <String, dynamic>{
      'schedule': <String, dynamic>{
        'sun': <String, dynamic>{
          'start': 0,
          'end': 86400000,
        },
        'sat': <String, dynamic>{
          'start': 32400000,
          'end': 61200000,
        },
        'time_zone': 'Europe/Berlin',
      },
      'ids': <dynamic>[
        'tiktok',
      ],
    };

/// `GET control/rewrite/list`: one rewrite to an address, and one
/// wildcard to a domain that is switched off.
List<dynamic> rewritesJson() => <dynamic>[
      <String, dynamic>{
        'domain': 'nas.home.example',
        'answer': '192.168.1.50',
        'enabled': true,
      },
      <String, dynamic>{
        'domain': '*.lan.example',
        'answer': 'nas.home.example',
        'enabled': false,
      },
    ];

/// `GET control/rewrite/settings`.
Map<String, dynamic> rewriteSettingsJson() => <String, dynamic>{
      'enabled': true,
    };

/// `GET control/filtering/check_host` for seven names, keyed by the name:
/// a blocked service, a custom block, a custom allow, a rewrite, nothing, a
/// rewrite by rule, and a name an allowlist lets through.
Map<String, dynamic> hostChecksJson() => <String, dynamic>{
      'www.tiktok.com': <String, dynamic>{
        'reason': 'FilteredBlockedService',
        'rule': '||tiktok.com^',
        'rules': <dynamic>[
          <String, dynamic>{
            'text': '||tiktok.com^',
            'filter_list_id': -2,
          },
        ],
        'service_name': 'tiktok',
        'cname': '',
        'ip_addrs': null,
        'filter_id': -2,
      },
      'blocked-by-custom.example': <String, dynamic>{
        'reason': 'FilteredBlackList',
        'rule': '||blocked-by-custom.example^',
        'rules': <dynamic>[
          <String, dynamic>{
            'text': '||blocked-by-custom.example^',
            'filter_list_id': 0,
          },
        ],
        'service_name': '',
        'cname': '',
        'ip_addrs': null,
        'filter_id': 0,
      },
      'wikipedia.org': <String, dynamic>{
        'reason': 'NotFilteredWhiteList',
        'rule': '@@||wikipedia.org^',
        'rules': <dynamic>[
          <String, dynamic>{
            'text': '@@||wikipedia.org^',
            'filter_list_id': 0,
          },
        ],
        'service_name': '',
        'cname': '',
        'ip_addrs': null,
        'filter_id': 0,
      },
      'nas.home.example': <String, dynamic>{
        'reason': 'Rewrite',
        'rule': '',
        'rules': <dynamic>[],
        'service_name': '',
        'cname': '',
        'ip_addrs': <dynamic>[
          '192.168.1.50',
        ],
        'filter_id': 0,
      },
      'example.com': <String, dynamic>{
        'reason': 'NotFilteredNotFound',
        'rule': '',
        'rules': <dynamic>[],
        'service_name': '',
        'cname': '',
        'ip_addrs': null,
        'filter_id': 0,
      },
      'rule-rewrite.example': <String, dynamic>{
        'reason': 'RewriteRule',
        'rule': '|rule-rewrite.example^\$dnsrewrite=10.0.0.7',
        'rules': <dynamic>[
          <String, dynamic>{
            'text': '|rule-rewrite.example^\$dnsrewrite=10.0.0.7',
            'filter_list_id': 0,
          },
        ],
        'service_name': '',
        'cname': '',
        'ip_addrs': null,
        'filter_id': 0,
      },
      'doubleclick.net': <String, dynamic>{
        'reason': 'NotFilteredWhiteList',
        'rule': '||doubleclick.net^',
        'rules': <dynamic>[
          <String, dynamic>{
            'text': '||doubleclick.net^',
            'filter_list_id': 1792423510,
          },
        ],
        'service_name': '',
        'cname': '',
        'ip_addrs': null,
        'filter_id': 1792423510,
      },
    };
