import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

/// Records where every request went, and answers with an empty count.
class _Recorder implements HttpClientAdapter {
  final List<Uri> seen = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options.uri);
    return ResponseBody.fromString(
      '{"pending":0,"approved":0,"available":0,"denied":0}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Ombi installs behind a reverse proxy often live under a sub-path, and the
/// generated routes all start with a slash. Dio 5 joins the base URL and the
/// path and then collapses the double slash, rather than resolving the path
/// against the host, so the sub-path is kept. This pins that down: a Dio that
/// resolved the way a browser does would send every call to the host root.
void main() {
  test('a sub-path in the base URL survives every call', () async {
    final _Recorder recorder = _Recorder();
    final OmbiClient client = OmbiClient(
      dio: Dio()..httpClientAdapter = recorder,
      baseUrl: 'http://ombi.test/ombi',
    );

    await client.rawRequestApi.getRequestCount();
    await client.rawRequestsApi
        .getRequestsMoviePendingByCountPositionSortSortOrder(
      count: '25',
      position: '0',
      sort: 'requestedDate',
      sortOrder: 'desc',
    );

    expect(recorder.seen.map((Uri u) => u.path), <String>[
      '/ombi/api/v1/Request/count',
      '/ombi/api/v2/Requests/movie/pending/25/0/requestedDate/desc',
    ]);
  });
}
