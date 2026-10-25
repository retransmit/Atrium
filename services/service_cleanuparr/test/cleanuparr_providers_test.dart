import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

const Instance _instance = Instance(
  id: 'cleanuparr-1',
  name: 'Cleanuparr',
  kind: ServiceKind.cleanuparr,
  localUrl: 'http://cleanuparr.local:11011/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

/// Serves a single page of events, the shape a history under 500 events has.
class _OnePageOfEvents implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> page = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'blocked',
          'timestamp': '2026-10-23T10:00:00Z',
          'eventType': 'QueueItemDeleted',
          'severity': 'Important',
          'message': 'All files blocked',
          'deleteReason': 'AllFilesBlocked',
        },
        <String, dynamic>{
          'id': 'stalled',
          'timestamp': '2026-10-23T09:00:00Z',
          'eventType': 'StalledStrike',
          'severity': 'Warning',
          'message': 'Stalled',
        },
        <String, dynamic>{
          'id': 'search',
          'timestamp': '2026-10-23T08:00:00Z',
          'eventType': 'SearchTriggered',
          'severity': 'Information',
          'message': 'Search triggered',
        },
      ],
      'page': 1,
      'pageSize': 500,
      'totalCount': 3,
      'totalPages': 1,
    };
    return ResponseBody.fromString(
      jsonEncode(page),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<List<String>> eventIdsFor(String? filter) async {
    final Dio dio = Dio()..httpClientAdapter = _OnePageOfEvents();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        cleanuparrApiProvider(_instance).overrideWith(
          (Ref ref) => CleanuparrApi(dio),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<List<CleanuparrEvent>>> sub =
        container.listen(cleanuparrEventsProvider(_instance), (_, __) {});
    addTearDown(sub.close);
    container.read(cleanuparrEventsFilterProvider(_instance).notifier).state =
        filter;
    final List<CleanuparrEvent> events =
        await container.read(cleanuparrEventsProvider(_instance).future);
    return events.map((CleanuparrEvent e) => e.id).toList();
  }

  group('category chips on a one-page history', () {
    test('All shows every event', () async {
      expect(await eventIdsFor(null), <String>['blocked', 'stalled', 'search']);
    });

    test('Malware shows only the blocked download', () async {
      expect(await eventIdsFor('malware'), <String>['blocked']);
    });

    test('Strikes shows only the strike', () async {
      expect(await eventIdsFor('strikes'), <String>['stalled']);
    });

    test('Deletions shows only the deleted item', () async {
      expect(await eventIdsFor('deletions'), <String>['blocked']);
    });
  });
}
