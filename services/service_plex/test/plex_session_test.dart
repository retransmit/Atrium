import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

void main() {
  group('PlexSession parsing', () {
    test('direct play, controllable player', () {
      final PlexSessionsResponse r = PlexSessionsResponse.fromJson(<String, dynamic>{
        'MediaContainer': <String, dynamic>{
          'Metadata': <dynamic>[
            <String, dynamic>{
              'title': 'Blade Runner',
              'type': 'movie',
              'thumb': '/library/metadata/10/thumb/1',
              'viewOffset': 600000,
              'duration': 6000000,
              'User': <String, dynamic>{'title': 'alice', 'thumb': 'http://x/y.png'},
              'Player': <String, dynamic>{
                'title': 'Living Room',
                'product': 'Plex for Apple TV',
                'machineIdentifier': 'abc123',
                'state': 'playing',
                'local': true,
                'protocolCapabilities': 'timeline,playback,navigation',
              },
              'Session': <String, dynamic>{'id': 'sess-1', 'bandwidth': 4200, 'location': 'lan'},
            },
          ],
        },
      });
      final PlexSession s = r.mediaContainer!.metadata.single;
      expect(s.sessionId, 'sess-1');
      expect(s.title, 'Blade Runner');
      expect(s.user?.title, 'alice');
      expect(s.player?.controllable, isTrue);
      expect(s.isTranscode, isFalse);
      expect(s.decisionLabel, 'Direct Play');
      expect(s.progress, closeTo(0.1, 0.001));
      expect(s.bandwidth, 4200);
      expect(s.location, 'lan');
    });

    test('transcode, non-controllable player, missing nested nodes', () {
      final PlexSessionsResponse r = PlexSessionsResponse.fromJson(<String, dynamic>{
        'MediaContainer': <String, dynamic>{
          'Metadata': <dynamic>[
            <String, dynamic>{
              'title': 'Ep',
              'grandparentTitle': 'Some Show',
              'Player': <String, dynamic>{
                'title': 'Web',
                'machineIdentifier': 'web1',
                'state': 'paused',
                'protocolCapabilities': 'timeline',
              },
              'TranscodeSession': <String, dynamic>{
                'videoDecision': 'transcode',
                'audioDecision': 'copy',
                'throttled': true,
              },
              'Session': <String, dynamic>{'id': 'sess-2'},
            },
          ],
        },
      });
      final PlexSession s = r.mediaContainer!.metadata.single;
      expect(s.player?.controllable, isFalse); // no 'playback' capability
      expect(s.isTranscode, isTrue);
      expect(s.decisionLabel, 'Transcode');
      expect(s.progress, 0.0); // no offset/duration
      expect(s.user, isNull);
    });

    test('empty container -> empty list', () {
      final PlexSessionsResponse r =
          PlexSessionsResponse.fromJson(<String, dynamic>{'MediaContainer': <String, dynamic>{}});
      expect(r.mediaContainer!.metadata, isEmpty);
    });
  });
}
