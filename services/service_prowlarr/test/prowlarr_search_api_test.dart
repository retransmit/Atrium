import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

import 'support/fake_prowlarr.dart';

void main() {
  late FakeProwlarr server;

  setUp(() => server = FakeProwlarr());

  test('getCategories reads the parent and subcategory tree', () async {
    final List<ProwlarrCategory> tree =
        await ProwlarrApi(dioFor(server)).getCategories();
    expect(tree.map((ProwlarrCategory c) => c.id), <int>[2000, 5000]);
    expect(
      tree.first.subCategories.map((ProwlarrCategory c) => c.id),
      <int>[2040, 2045],
    );
    expect(tree.first.subCategories.first.shortName, 'HD');
  });

  test('search sends each indexer and category as its own parameter',
      () async {
    await ProwlarrApi(dioFor(server))
        .search('dune', indexerIds: <int>[-2, 5], categories: <int>[2000]);
    final Uri uri = server.requests.last.uri;
    expect(uri.queryParametersAll['indexerIds'], <String>['-2', '5']);
    expect(uri.queryParametersAll['categories'], <String>['2000']);
  });

  test('search with no filter sends neither parameter', () async {
    await ProwlarrApi(dioFor(server)).search('dune');
    final Uri uri = server.requests.last.uri;
    expect(uri.queryParameters.containsKey('indexerIds'), isFalse);
    expect(uri.queryParameters.containsKey('categories'), isFalse);
  });
}
