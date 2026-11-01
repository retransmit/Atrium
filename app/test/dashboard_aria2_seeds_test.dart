import 'package:atrium/src/dashboard/widgets/downloads_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_aria2/service_aria2.dart';

import 'dashboard_widgets_test.dart' show makeInstance, pumpBody;

/// A finished torrent stays `active` in aria2 while it seeds, so the card
/// has to leave it out the way it leaves out the other clients' seeds.
void main() {
  testWidgets('an aria2 seed is not listed as an active download',
      (WidgetTester tester) async {
    final Instance aria2 = makeInstance(ServiceKind.aria2);

    await pumpBody(
      tester,
      <Override>[
        aria2SnapshotProvider(aria2).overrideWith(
          (Ref ref) async => const Aria2Snapshot(
            stat: Aria2GlobalStat(),
            version: Aria2Version(),
            active: <Aria2Download>[
              Aria2Download(
                gid: 'seed',
                status: 'active',
                seeder: true,
                totalLength: 100,
                completedLength: 100,
                torrentName: 'Seeding Pack',
              ),
              Aria2Download(
                gid: 'dl',
                status: 'active',
                totalLength: 100,
                completedLength: 40,
                torrentName: 'Still Downloading',
              ),
            ],
            waiting: <Aria2Download>[],
            stopped: <Aria2Download>[],
          ),
        ),
      ],
      DashboardDownloadsWidget(
        qbitInstances: const <Instance>[],
        sabInstances: const <Instance>[],
        nzbgetInstances: const <Instance>[],
        delugeInstances: const <Instance>[],
        transmissionInstances: const <Instance>[],
        rtorrentInstances: const <Instance>[],
        aria2Instances: <Instance>[aria2],
      ),
    );

    expect(find.text('Still Downloading'), findsOneWidget);
    expect(find.text('Seeding Pack'), findsNothing);
  });
}
