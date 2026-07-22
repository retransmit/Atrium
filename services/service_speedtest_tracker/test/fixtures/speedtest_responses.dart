const Map<String, dynamic> currentResult = <String, dynamic>{
  'id': 42,
  'service': 'ookla',
  'ping': '12.4',
  'download': 100000000,
  'upload': 25000000,
  'download_bits': 800000000,
  'healthy': true,
  'status': 'completed',
  'data': <String, dynamic>{
    'isp': 'Example Fiber',
    'timestamp': '2026-07-20T18:15:00Z',
    'packetLoss': 0.5,
    'ping': <String, dynamic>{
      'latency': 12.4,
      'jitter': 1.8,
      'low': 10.1,
      'high': 20.2,
    },
    'server': <String, dynamic>{
      'id': 1234,
      'name': 'Example Speedtest',
      'host': 'speed.example.test',
      'location': 'Seattle, WA',
      'country': 'United States',
    },
    'result': <String, dynamic>{
      'url': 'https://www.speedtest.net/result/c/example-result',
    },
  },
  'created_at': '2026-07-20 18:14:40',
  'updated_at': '2026-07-20 18:15:10',
};

const Map<String, dynamic> legacyResult = <String, dynamic>{
  'id': '7',
  'ping': 25,
  'download': '12500000',
  'upload': '6250000',
  'status': 'completed',
  'created_at': '2024-01-02 03:04:05',
};

const Map<String, dynamic> runningResult = <String, dynamic>{
  'id': 43,
  'status': 'running',
  'created_at': '2026-07-20 18:20:00',
};

Map<String, dynamic> resultEnvelope(Map<String, dynamic> result) =>
    <String, dynamic>{'data': result, 'message': 'ok'};

Map<String, dynamic> resultPage(
  List<Map<String, dynamic>> results, {
  int currentPage = 1,
  int lastPage = 1,
}) =>
    <String, dynamic>{
      'data': results,
      'links': <String, dynamic>{
        'next': currentPage < lastPage
            ? 'https://tracker.example.test/api/v1/results?page=2'
            : null,
      },
      'meta': <String, dynamic>{
        'current_page': currentPage,
        'last_page': lastPage,
      },
    };
