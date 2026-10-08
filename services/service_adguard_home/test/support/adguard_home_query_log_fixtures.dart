/// What AdGuard Home v0.107.79 answered for the query log and the two lists
/// its actions read, captured from a real server on 2026-10-08. Keep these
/// as the server sent them: tests that need something else build on a copy.
library;

/// `GET control/querylog`: fifteen entries picked from a real log so that
/// every kind the server produced is here once. Newest first, as sent.
/// Among them: an answer from the cache, an NXDOMAIN, an entry with no
/// `answer` at all, one blocked by a list and one by a custom rule, one
/// allowed by a rule, the three kinds of rewrite, safe search, parental
/// control, a blocked service, and a client known only by its runtime name.
Map<String, dynamic> queryLogJson() => <String, dynamic>{
      'data': <dynamic>[
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '172.66.157.237',
              'ttl': 262,
            },
            <String, dynamic>{
              'type': 'A',
              'value': '104.20.26.136',
              'ttl': 262,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '365.87117',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'example.org',
            'type': 'A',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:29:32.37724677Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '127.0.0.1',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.043654',
          'filterId': -1,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'localhost',
            'type': 'A',
          },
          'reason': 'RewriteEtcHosts',
          'rule': '127.0.0.1 localhost',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': -1,
              'text': '127.0.0.1 localhost',
            },
            <String, dynamic>{
              'filter_list_id': -1,
              'text': '::1 localhost',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:40.089649146Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.140851',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'no-such-name-atrium-test.invalid',
            'type': 'A',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NXDOMAIN',
          'time': '2026-10-07T20:25:40.086772911Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '94.140.14.35',
              'ttl': 3595,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.14071',
          'filterId': -3,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'pornhub.com',
            'type': 'A',
          },
          'reason': 'FilteredParental',
          'rule': 'parental CATEGORY_BLACKLISTED',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': -3,
              'text': 'parental CATEGORY_BLACKLISTED',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:40.085136311Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'CNAME',
              'value': 'restrictmoderate.youtube.com.',
              'ttl': 10,
            },
            <String, dynamic>{
              'type': 'A',
              'value': '216.239.38.119',
              'ttl': 2139,
            },
          ],
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.207889',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'www.youtube.com',
            'type': 'A',
          },
          'reason': 'FilteredSafeSearch',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.069050919Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '10.0.0.7',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.082749',
          'filterId': 0,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'rule-rewrite.example',
            'type': 'A',
          },
          'reason': 'RewriteRule',
          'rule': '|rule-rewrite.example^\$dnsrewrite=10.0.0.7',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': 0,
              'text': '|rule-rewrite.example^\$dnsrewrite=10.0.0.7',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.064889725Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '192.168.1.50',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.058002',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'nas.home.example',
            'type': 'A',
          },
          'reason': 'Rewrite',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.062866403Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'CNAME',
              'value': 'dyna.wikimedia.org.',
              'ttl': 69,
            },
            <String, dynamic>{
              'type': 'A',
              'value': '103.102.166.224',
              'ttl': 69,
            },
          ],
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.06785',
          'filterId': 0,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'en.wikipedia.org',
            'type': 'A',
          },
          'reason': 'NotFilteredWhiteList',
          'rule': '@@||wikipedia.org^',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': 0,
              'text': '@@||wikipedia.org^',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.060443385Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '0.0.0.0',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.068652',
          'filterId': 0,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'blocked-by-custom.example',
            'type': 'A',
          },
          'reason': 'FilteredBlackList',
          'rule': '||blocked-by-custom.example^',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': 0,
              'text': '||blocked-by-custom.example^',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.05887478Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '0.0.0.0',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.104131',
          'filterId': 1,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'adservice.google.com',
            'type': 'A',
          },
          'reason': 'FilteredBlackList',
          'rule': '||adservice.google.',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': 1,
              'text': '||adservice.google.',
            },
          ],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.056944249Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'MX',
              'value': '10 alt1.gmail-smtp-in.l.google.com.',
              'ttl': 1187,
            },
            <String, dynamic>{
              'type': 'MX',
              'value': '40 alt4.gmail-smtp-in.l.google.com.',
              'ttl': 1187,
            },
            <String, dynamic>{
              'type': 'MX',
              'value': '5 gmail-smtp-in.l.google.com.',
              'ttl': 1187,
            },
            <String, dynamic>{
              'type': 'MX',
              'value': '30 alt3.gmail-smtp-in.l.google.com.',
              'ttl': 1187,
            },
            <String, dynamic>{
              'type': 'MX',
              'value': '20 alt2.gmail-smtp-in.l.google.com.',
              'ttl': 1187,
            },
          ],
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.10912',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'gmail.com',
            'type': 'MX',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.050810796Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.108979',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'github.com',
            'type': 'HTTPS',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.048759041Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '172.66.147.243',
              'ttl': 89,
            },
            <String, dynamic>{
              'type': 'A',
              'value': '104.20.23.154',
              'ttl': 89,
            },
          ],
          'answer_dnssec': false,
          'cached': true,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.12484',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'example.com',
            'type': 'A',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:36.045135445Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '0.0.0.0',
              'ttl': 10,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '172.17.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'Laptop',
            'disallowed_rule': '172.17.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '0.29531799999999997',
          'filterId': -2,
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'www.tiktok.com',
            'type': 'A',
          },
          'reason': 'FilteredBlockedService',
          'rule': '||tiktok.com^',
          'rules': <dynamic>[
            <String, dynamic>{
              'filter_list_id': -2,
              'text': '||tiktok.com^',
            },
          ],
          'service_name': 'tiktok',
          'status': 'NOERROR',
          'time': '2026-10-07T20:25:35.332629051Z',
          'upstream': '',
        },
        <String, dynamic>{
          'answer': <dynamic>[
            <String, dynamic>{
              'type': 'A',
              'value': '172.67.180.78',
              'ttl': 300,
            },
            <String, dynamic>{
              'type': 'A',
              'value': '104.21.43.147',
              'ttl': 300,
            },
          ],
          'answer_dnssec': false,
          'cached': false,
          'client': '127.0.0.1',
          'client_info': <String, dynamic>{
            'whois': <String, dynamic>{},
            'name': 'localhost',
            'disallowed_rule': '127.0.0.1',
            'disallowed': false,
          },
          'client_proto': '',
          'elapsedMs': '28.702257',
          'question': <String, dynamic>{
            'class': 'IN',
            'name': 'radarr.video',
            'type': 'A',
          },
          'reason': 'NotFilteredNotFound',
          'rules': <dynamic>[],
          'status': 'NOERROR',
          'time': '2026-10-07T18:31:41.552491023Z',
          'upstream': 'https://dns10.quad9.net:443/dns-query',
        },
      ],
      'oldest': '2026-10-07T18:31:41.552491023Z',
    };

/// `GET control/querylog/config`. The interval is in milliseconds.
Map<String, dynamic> queryLogConfigJson() => <String, dynamic>{
      'ignored': <dynamic>[],
      'interval': 7776000000,
      'enabled': true,
      'ignored_enabled': false,
      'anonymize_client_ip': false,
    };

/// `GET control/access/list` on a fresh install.
Map<String, dynamic> accessListJson() => <String, dynamic>{
      'allowed_clients': <dynamic>[],
      'disallowed_clients': <dynamic>[],
      'blocked_hosts': <dynamic>['version.bind', 'id.server', 'hostname.bind'],
    };

/// `GET control/clients`, cut down to what is read: one persistent client
/// and two the server learned of by itself.
Map<String, dynamic> clientsJson() => <String, dynamic>{
      'clients': <dynamic>[
        <String, dynamic>{
          'name': 'Laptop',
          'ids': <dynamic>['172.17.0.1'],
          'tags': <dynamic>['device_laptop'],
          'use_global_settings': true,
          'use_global_blocked_services': true,
        },
      ],
      'auto_clients': <dynamic>[
        <String, dynamic>{
          'whois_info': <String, dynamic>{},
          'ip': '127.0.0.1',
          'name': 'localhost',
          'source': 'etc/hosts',
        },
      ],
      'supported_tags': <dynamic>['device_laptop', 'device_phone'],
    };
