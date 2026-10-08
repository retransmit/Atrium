/// What AdGuard Home v0.107.79 answered about its clients, captured from a
/// real server on 2026-10-08. Keep these as the server sent them: tests that
/// need something else build on a copy.
library;

/// `GET control/clients`: three persistent clients and the runtime clients
/// of a container.
///
///  * "Kids tablet" has everything of its own: a MAC address and a range as
///    identifiers, two tags, its own protection settings with safe search
///    on for all but one engine, three blocked services and a pause
///    schedule for the weekend.
///  * "Laptop" uses the global settings. The server sends `null` for its
///    blocked services and its upstreams.
///  * "Work phone" goes by a ClientID, has upstream servers of its own with
///    a cache, and is left out of the query log.
///
/// 172.17.0.1 is both Laptop's identifier and a runtime client. The last
/// runtime client was added by hand, in the shape the API documents: the
/// test server never sees a public address, so it has no WHOIS to send.
Map<String, dynamic> clientListJson() => <String, dynamic>{
      'clients': <dynamic>[
        <String, dynamic>{
          'safe_search': <String, dynamic>{
            'enabled': true,
            'bing': true,
            'duckduckgo': true,
            'ecosia': true,
            'google': true,
            'pixabay': true,
            'yandex': true,
            'youtube': false,
          },
          'blocked_services_schedule': <String, dynamic>{
            'sun': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'sat': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'time_zone': 'Europe/Berlin',
          },
          'name': 'Kids tablet',
          'blocked_services': <dynamic>[
            'tiktok',
            'roblox',
            'youtube',
          ],
          'ids': <dynamic>[
            '192.168.50.0/28',
            'aa:bb:cc:dd:ee:01',
          ],
          'tags': <dynamic>[
            'device_tablet',
            'user_child',
          ],
          'upstreams': <dynamic>[],
          'filtering_enabled': true,
          'parental_enabled': true,
          'safebrowsing_enabled': true,
          'safesearch_enabled': true,
          'use_global_blocked_services': false,
          'use_global_settings': false,
          'ignore_querylog': false,
          'ignore_statistics': false,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': false,
        },
        <String, dynamic>{
          'safe_search': <String, dynamic>{
            'enabled': false,
            'bing': false,
            'duckduckgo': false,
            'ecosia': false,
            'google': false,
            'pixabay': false,
            'yandex': false,
            'youtube': false,
          },
          'blocked_services_schedule': <String, dynamic>{
            'time_zone': 'UTC',
          },
          'name': 'Laptop',
          'blocked_services': null,
          'ids': <dynamic>[
            '172.17.0.1',
          ],
          'tags': <dynamic>[
            'device_laptop',
          ],
          'upstreams': null,
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': true,
          'use_global_settings': true,
          'ignore_querylog': false,
          'ignore_statistics': false,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': false,
        },
        <String, dynamic>{
          'safe_search': <String, dynamic>{
            'enabled': false,
            'bing': true,
            'duckduckgo': true,
            'ecosia': true,
            'google': true,
            'pixabay': true,
            'yandex': true,
            'youtube': true,
          },
          'blocked_services_schedule': <String, dynamic>{
            'time_zone': 'UTC',
          },
          'name': 'Work phone',
          'blocked_services': <dynamic>[],
          'ids': <dynamic>[
            'work-phone',
          ],
          'tags': <dynamic>[
            'device_phone',
            'os_android',
          ],
          'upstreams': <dynamic>[
            '1.1.1.1',
            '[/corp.example/]10.0.0.1',
          ],
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': true,
          'use_global_settings': true,
          'ignore_querylog': true,
          'ignore_statistics': false,
          'upstreams_cache_size': 4096,
          'upstreams_cache_enabled': true,
        },
      ],
      'auto_clients': <dynamic>[
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': 'ff02::1',
          'name': 'ip6-allnodes',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': 'ff02::2',
          'name': 'ip6-allrouters',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': '172.17.0.2',
          'name': 'aa71e05dc8fb',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': '127.0.0.1',
          'name': 'localhost',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': '::1',
          'name': 'localhost',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': 'fe00::',
          'name': 'ip6-localnet',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': '172.17.0.1',
          'name': '',
          'source': 'ARP',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': 'ff00::',
          'name': 'ip6-mcastprefix',
          'source': 'etc/hosts',
        },
        <String, dynamic>{
          'whois_info': <String, dynamic>{
            'orgname': 'Example Networks',
            'country': 'DE',
            'city': 'Berlin',
          },
          'ip': '203.0.113.9',
          'name': '',
          'source': 'WHOIS',
        },
      ],
      'supported_tags': <dynamic>[
        'device_audio',
        'device_camera',
        'device_gameconsole',
        'device_laptop',
        'device_nas',
        'device_other',
        'device_pc',
        'device_phone',
        'device_printer',
        'device_securityalarm',
        'device_tablet',
        'device_tv',
        'os_android',
        'os_ios',
        'os_linux',
        'os_macos',
        'os_other',
        'os_windows',
        'user_admin',
        'user_child',
        'user_regular',
      ],
    };

/// `POST control/clients/search` for the two top clients, a MAC address, a
/// ClientID, an address inside a client's range and an address nobody
/// knows. A list of objects with one entry each. A persistent client comes
/// back whole, with no `whois_info`; anything else with the name the server
/// has for it, or none.
List<dynamic> clientSearchJson() => <dynamic>[
      <String, dynamic>{
        '172.17.0.1': <String, dynamic>{
          'disallowed': false,
          'safe_search': <String, dynamic>{
            'enabled': false,
            'bing': false,
            'duckduckgo': false,
            'ecosia': false,
            'google': false,
            'pixabay': false,
            'yandex': false,
            'youtube': false,
          },
          'blocked_services_schedule': <String, dynamic>{
            'time_zone': 'UTC',
          },
          'name': 'Laptop',
          'blocked_services': null,
          'ids': <dynamic>[
            '172.17.0.1',
          ],
          'tags': <dynamic>[
            'device_laptop',
          ],
          'upstreams': null,
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': true,
          'use_global_settings': true,
          'ignore_querylog': false,
          'ignore_statistics': false,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': false,
        },
      },
      <String, dynamic>{
        '127.0.0.1': <String, dynamic>{
          'disallowed': false,
          'whois_info': <String, dynamic>{},
          'safe_search': null,
          'blocked_services_schedule': null,
          'name': 'localhost',
          'blocked_services': null,
          'ids': <dynamic>[
            '127.0.0.1',
          ],
          'tags': null,
          'upstreams': null,
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': false,
          'use_global_settings': false,
          'ignore_querylog': null,
          'ignore_statistics': null,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': null,
        },
      },
      <String, dynamic>{
        'aa:bb:cc:dd:ee:01': <String, dynamic>{
          'disallowed': false,
          'safe_search': <String, dynamic>{
            'enabled': true,
            'bing': true,
            'duckduckgo': true,
            'ecosia': true,
            'google': true,
            'pixabay': true,
            'yandex': true,
            'youtube': false,
          },
          'blocked_services_schedule': <String, dynamic>{
            'sun': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'sat': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'time_zone': 'Europe/Berlin',
          },
          'name': 'Kids tablet',
          'blocked_services': <dynamic>[
            'tiktok',
            'roblox',
            'youtube',
          ],
          'ids': <dynamic>[
            '192.168.50.0/28',
            'aa:bb:cc:dd:ee:01',
          ],
          'tags': <dynamic>[
            'device_tablet',
            'user_child',
          ],
          'upstreams': <dynamic>[],
          'filtering_enabled': true,
          'parental_enabled': true,
          'safebrowsing_enabled': true,
          'safesearch_enabled': true,
          'use_global_blocked_services': false,
          'use_global_settings': false,
          'ignore_querylog': false,
          'ignore_statistics': false,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': false,
        },
      },
      <String, dynamic>{
        'work-phone': <String, dynamic>{
          'disallowed': false,
          'safe_search': <String, dynamic>{
            'enabled': false,
            'bing': true,
            'duckduckgo': true,
            'ecosia': true,
            'google': true,
            'pixabay': true,
            'yandex': true,
            'youtube': true,
          },
          'blocked_services_schedule': <String, dynamic>{
            'time_zone': 'UTC',
          },
          'name': 'Work phone',
          'blocked_services': <dynamic>[],
          'ids': <dynamic>[
            'work-phone',
          ],
          'tags': <dynamic>[
            'device_phone',
            'os_android',
          ],
          'upstreams': <dynamic>[
            '1.1.1.1',
            '[/corp.example/]10.0.0.1',
          ],
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': true,
          'use_global_settings': true,
          'ignore_querylog': true,
          'ignore_statistics': false,
          'upstreams_cache_size': 4096,
          'upstreams_cache_enabled': true,
        },
      },
      <String, dynamic>{
        '192.168.50.3': <String, dynamic>{
          'disallowed': false,
          'safe_search': <String, dynamic>{
            'enabled': true,
            'bing': true,
            'duckduckgo': true,
            'ecosia': true,
            'google': true,
            'pixabay': true,
            'yandex': true,
            'youtube': false,
          },
          'blocked_services_schedule': <String, dynamic>{
            'sun': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'sat': <String, dynamic>{
              'start': 32400000,
              'end': 61200000,
            },
            'time_zone': 'Europe/Berlin',
          },
          'name': 'Kids tablet',
          'blocked_services': <dynamic>[
            'tiktok',
            'roblox',
            'youtube',
          ],
          'ids': <dynamic>[
            '192.168.50.0/28',
            'aa:bb:cc:dd:ee:01',
          ],
          'tags': <dynamic>[
            'device_tablet',
            'user_child',
          ],
          'upstreams': <dynamic>[],
          'filtering_enabled': true,
          'parental_enabled': true,
          'safebrowsing_enabled': true,
          'safesearch_enabled': true,
          'use_global_blocked_services': false,
          'use_global_settings': false,
          'ignore_querylog': false,
          'ignore_statistics': false,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': false,
        },
      },
      <String, dynamic>{
        '203.0.113.9': <String, dynamic>{
          'disallowed': false,
          'whois_info': <String, dynamic>{},
          'safe_search': null,
          'blocked_services_schedule': null,
          'name': '',
          'blocked_services': null,
          'ids': <dynamic>[
            '203.0.113.9',
          ],
          'tags': null,
          'upstreams': null,
          'filtering_enabled': false,
          'parental_enabled': false,
          'safebrowsing_enabled': false,
          'safesearch_enabled': false,
          'use_global_blocked_services': false,
          'use_global_settings': false,
          'ignore_querylog': null,
          'ignore_statistics': null,
          'upstreams_cache_size': 0,
          'upstreams_cache_enabled': null,
        },
      },
    ];

/// `GET control/safesearch/status`.
Map<String, dynamic> safeSearchJson() => <String, dynamic>{
      'enabled': true,
      'bing': true,
      'duckduckgo': true,
      'ecosia': true,
      'google': true,
      'pixabay': true,
      'yandex': true,
      'youtube': true,
    };

/// `GET control/blocked_services/all`, cut down from 139 services to six
/// with short icons, and each to its first two rules. The groups are all
/// the server has. An icon is an SVG in base64.
Map<String, dynamic> blockedServicesJson() => <String, dynamic>{
      'blocked_services': <dynamic>[
        <String, dynamic>{
          'id': 'tiktok',
          'name': 'TikTok',
          'icon_svg': 'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9ImN1cnJlbnRDb2xvciIgdmlld0JveD0iMCAwIDUwIDUwIj48cGF0aCBkPSJNNDEgNEg5QzYuMjQzIDQgNCA2LjI0MyA0IDl2MzJjMCAyLjc1NyAyLjI0MyA1IDUgNWgzMmMyLjc1NyAwIDUtMi4yNDMgNS01VjljMC0yLjc1Ny0yLjI0My01LTUtNXptLTMuOTk0IDE4LjMyM2E3LjQ4MiA3LjQ4MiAwIDAgMS0uNjkuMDM1IDcuNDkyIDcuNDkyIDAgMCAxLTYuMjY5LTMuMzg4djExLjUzN2E4LjUyNyA4LjUyNyAwIDEgMS04LjUyNy04LjUyN2MuMTc4IDAgLjM1Mi4wMTYuNTI3LjAyN3Y0LjIwMmMtLjE3NS0uMDIxLS4zNDctLjA1My0uNTI3LS4wNTNhNC4zNTEgNC4zNTEgMCAxIDAgMCA4LjcwNGMyLjQwNCAwIDQuNTI3LTEuODk0IDQuNTI3LTQuMjk4bC4wNDItMTkuNTk0aDQuMDE2YTcuNDg4IDcuNDg4IDAgMCAwIDYuOTAxIDYuNjg1djQuNjd6IiAvPjwvc3ZnPg==',
          'rules': <dynamic>[
            '||amemv.com^',
            '||bdurl.com^',
          ],
          'group_id': 'social_network',
        },
        <String, dynamic>{
          'id': 'youtube',
          'name': 'YouTube',
          'icon_svg': 'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9ImN1cnJlbnRDb2xvciIgdmlld0JveD0iMCAwIDI0IDI0Ij48cGF0aCBkPSJNMTkuNjk1IDQuMDRTMTUuMzQ4IDMuMiAxMiAzLjJzLTcuNjk1Ljg0LTcuNjk1Ljg0TDEuNjAyIDcuMnY5LjZsMi43MDMgMy4xNnM0LjM0Ny44NCA3LjY5NS44NCA3LjY5NS0uODQgNy42OTUtLjg0bDIuNzAzLTMuMTZWMTIgNy4yek05LjYwMiAxNS42OFY4LjMyTDE2IDEyem0wIDAiIC8+PHBhdGggZD0iTTE5LjIgNGEzLjE5OCAzLjE5OCAwIDEgMCAwIDYuMzk4YzEuNzY5IDAgMy4xOTgtMS40MyAzLjE5OC0zLjE5OUMyMi4zOTggNS40MzQgMjAuOTY4IDQgMTkuMiA0em0wIDkuNjAyYTMuMTk4IDMuMTk4IDAgMSAwIDAgNi4zOThjMS43NjkgMCAzLjE5OC0xLjQzNCAzLjE5OC0zLjIgMC0xLjc2OS0xLjQzLTMuMTk4LTMuMTk5LTMuMTk4ek0xLjYwMSA3LjE5OWMwIDEuNzcgMS40MyAzLjIgMy4xOTkgMy4yIDEuNzY1IDAgMi4zOTgtMS40MyAyLjM5OC0zLjJDNy4yIDUuNDM0IDYuNTY2IDQgNC44MDEgNCAzLjAzIDQgMS42IDUuNDM0IDEuNiA3LjJ6TTQuOCAxMy42MDJjLTEuNzcgMC0zLjIgMS40My0zLjIgMy4xOTlBMy4xOTggMy4xOTggMCAxIDAgOCAxNi44YzAtMS43Ny0xLjQzNC0zLjItMy4yLTMuMnptMCAwIiAvPjwvc3ZnPg==',
          'rules': <dynamic>[
            '||ggpht.cn^',
            '||ggpht.com^',
          ],
          'group_id': 'streaming',
        },
        <String, dynamic>{
          'id': 'roblox',
          'name': 'Roblox',
          'icon_svg': 'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9ImN1cnJlbnRDb2xvciIgdmlld0JveD0iMCAwIDI0IDI0Ij48cGF0aCBkPSJtMTMuMzgzIDE0LjM0MS0zLjcyNi0uOTU4Ljk1OS0zLjcyNiAzLjcyNi45NTktLjk2IDMuNzI2ek00LjkxMyAwIDAgMTkuMDg4IDE5LjA4OCAyNCAyNCA0LjkxMiA0LjkxMiAweiIgLz48L3N2Zz4=',
          'rules': <dynamic>[
            '||blox.com^',
            '||rbx.cn^',
          ],
          'group_id': 'gaming',
        },
        <String, dynamic>{
          'id': 'netflix',
          'name': 'Netflix',
          'icon_svg': 'PHN2ZyBmaWxsPSJjdXJyZW50Q29sb3IiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgIHZpZXdCb3g9IjAgMCAzMCAzMCI+PHBhdGggZD0iTTI0LDRINkM0Ljg5NSw0LDQsNC44OTUsNCw2djE4YzAsMS4xMDUsMC44OTUsMiwyLDJoMThjMS4xMDUsMCwyLTAuODk1LDItMlY2QzI2LDQuODk1LDI1LjEwNSw0LDI0LDR6IE0xOSwyMmMwLDAtMS41LTAuMjMyLTMtMC4yMzJsLTItNS41MDd2NS41MDdjLTEuNSwwLTMsMC4yMzItMywwLjIzMlY4aDNsMiw1LjZWOGgzVjIyeiIgLz48L3N2Zz4=',
          'rules': <dynamic>[
            '|netflix.com.edgesuite.net^',
            '||dualstack.apiproxy-*.amazonaws.com^',
          ],
          'group_id': 'streaming',
        },
        <String, dynamic>{
          'id': 'meta_ai',
          'name': 'Meta AI',
          'icon_svg': 'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9ImN1cnJlbnRDb2xvciIgdmlld0JveD0iMCAwIDI0IDI0Ij48cGF0aCBkPSJNMTIgMGExMiAxMiAwIDEgMSAwIDI0IDEyIDEyIDAgMCAxIDAtMjRtMCAzLjZhOC40IDguNCAwIDEgMCAwIDE2LjggOC40IDguNCAwIDAgMCAwLTE2LjgiLz48L3N2Zz4=',
          'rules': <dynamic>[
            '||meta.ai^',
          ],
          'group_id': 'ai',
        },
        <String, dynamic>{
          'id': 'twitter',
          'name': 'X (formerly Twitter)',
          'icon_svg': 'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9ImN1cnJlbnRDb2xvciIgdmlld0JveD0iMCAwIDI0IDI0Ij48cGF0aCBkPSJNMTguMjQ0IDIuMjVoMy4zMDhsLTcuMjI3IDguMjYgOC41MDIgMTEuMjRIMTYuMTdsLTUuMjE0LTYuODE3TDQuOTkgMjEuNzVIMS42OGw3LjczLTguODM1TDEuMjU0IDIuMjVIOC4wOGw0LjcxMyA2LjIzMXptLTEuMTYxIDE3LjUyaDEuODMzTDcuMDg0IDQuMTI2SDUuMTE3eiIvPjwvc3ZnPg==',
          'rules': <dynamic>[
            '||ads-twitter.com^',
            '||cms-twdigitalassets.com^',
          ],
          'group_id': 'social_network',
        },
      ],
      'groups': <dynamic>[
        <String, dynamic>{
          'id': 'ai',
        },
        <String, dynamic>{
          'id': 'cdn',
        },
        <String, dynamic>{
          'id': 'dating',
        },
        <String, dynamic>{
          'id': 'gambling',
        },
        <String, dynamic>{
          'id': 'gaming',
        },
        <String, dynamic>{
          'id': 'hosting',
        },
        <String, dynamic>{
          'id': 'messenger',
        },
        <String, dynamic>{
          'id': 'privacy',
        },
        <String, dynamic>{
          'id': 'shopping',
        },
        <String, dynamic>{
          'id': 'social_network',
        },
        <String, dynamic>{
          'id': 'software',
        },
        <String, dynamic>{
          'id': 'streaming',
        },
      ],
    };
