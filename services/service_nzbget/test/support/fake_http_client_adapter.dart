import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef ResponseFactory = ({int status, Object? data}) Function(
  RequestOptions options,
);

class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.responseFactory, {this.headersFactory});

  final ResponseFactory responseFactory;
  final Map<String, List<String>> Function(RequestOptions options)?
      headersFactory;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final ({Object? data, int status}) response = responseFactory(options);
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        ...?headersFactory?.call(options),
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
