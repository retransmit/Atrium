import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> posts = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bool post = options.method == 'POST';
    if (post) posts.add(options);
    return ResponseBody.fromString(
      post ? '{"id": 9}' : '[]',
      post ? 201 : 200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

const Instance _instance = Instance(
  id: 'sonarr-test-1',
  name: 'Sonarr Test',
  kind: ServiceKind.sonarr,
  localUrl: 'http://localhost:8989',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'test-key'),
);

void main() {
  testWidgets('adding pops only the sheet, and the screen under it stays',
      (WidgetTester tester) async {
    final _Adapter adapter = _Adapter();
    final Dio dio = Dio()..httpClientAdapter = adapter;
    const SonarrSeries series =
        SonarrSeries(title: 'Severance', tvdbId: 371980);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sonarrApiProvider(_instance).overrideWith((ref) => SonarrApi(dio)),
          sonarrRootFoldersProvider(_instance).overrideWith(
            (ref) => <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'path': '/tv'},
            ],
          ),
          sonarrQualityProfilesProvider(_instance).overrideWith(
            (ref) => <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'name': 'HD-1080p'},
            ],
          ),
          sonarrTagsProvider(_instance)
              .overrideWith((ref) => <Map<String, dynamic>>[]),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Base'),
                  ElevatedButton(
                    // Opened straight from a screen, with no search route
                    // above it, the way a share opens it.
                    onPressed: () => showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SonarrAddSeriesSheet(
                        instance: _instance,
                        series: series,
                      ),
                    ),
                    child: const Text('Open Sheet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final Finder add = find.widgetWithText(FilledButton, 'Add Series');
    await tester.scrollUntilVisible(add, 100);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(adapter.posts, hasLength(1));
    expect(find.byType(SonarrAddSeriesSheet), findsNothing);
    expect(find.text('Base'), findsOneWidget);
  });
}
