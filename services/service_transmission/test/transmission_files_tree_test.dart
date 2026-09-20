import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

void main() {
  const List<TransmissionFile> files = <TransmissionFile>[
    TransmissionFile(
      name: 'show/s01/e01.mkv',
      length: 100,
      bytesCompleted: 100,
    ),
    TransmissionFile(
      name: 'show/s01/e02.mkv',
      length: 100,
      bytesCompleted: 50,
    ),
    // Nothing of it yet, which is the model's default.
    TransmissionFile(name: 'show/readme.txt', length: 10, wanted: false),
  ];

  test('nests folders from the slash-separated paths', () {
    final TransmissionFileNode root = buildTransmissionFileTree(files);

    expect(root.children.single.name, 'show');
    final TransmissionFileNode show = root.children.single;
    expect(
      show.children.map((TransmissionFileNode n) => n.name),
      <String>['s01', 'readme.txt'],
    );
    final TransmissionFileNode s01 = show.children.first;
    expect(s01.isFolder, isTrue);
    expect(
      s01.children.map((TransmissionFileNode n) => n.fileIndex),
      <int>[0, 1],
    );
    expect(show.children.last.fileIndex, 2);
    expect(show.children.last.isFolder, isFalse);
  });

  test('a folder sums its files and knows which indices it holds', () {
    final TransmissionFileNode show =
        buildTransmissionFileTree(files).children.single;

    expect(show.length, 210);
    expect(show.bytesCompleted, 150);
    expect(show.progress, closeTo(150 / 210, 0.0001));
    expect(show.indices, <int>[0, 1, 2]);
    expect(show.allWanted, isFalse);
    expect(show.anyWanted, isTrue);
    expect(show.children.first.allWanted, isTrue);
  });

  test('a single-file torrent is one file at the top level', () {
    final TransmissionFileNode root = buildTransmissionFileTree(
      const <TransmissionFile>[TransmissionFile(name: 'film.mkv', length: 5)],
    );
    expect(root.children.single.isFolder, isFalse);
    expect(root.children.single.path, 'film.mkv');
  });
}
