import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';
import 'package:service_slskd/src/browse/slskd_browse_models_ui.dart';
import 'package:service_slskd/src/searches/slskd_search_models_ui.dart';

void main() {
  group('Slskd Transfers Models', () {
    test('SlskdTransfer deserialization & computations', () {
      final json = <String, dynamic>{
        'id': '6fa459ea-ee8a-3ca4-894e-db77e160355e',
        'batchId': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'username': 'MusicLover42',
        'direction': 'Download',
        'filename': 'Music\\Daft Punk\\Discovery\\01 - One More Time.flac',
        'size': 35000000,
        'state': 'InProgress',
        'requestedAt': '2026-10-24T12:00:00Z',
        'startedAt': '2026-10-24T12:00:05Z',
        'bytesTransferred': 17500000,
        'averageSpeed': 1750000.0,
        'placeInQueue': 1,
        'attempts': 1,
      };

      final transfer = SlskdTransfer.fromJson(json);

      expect(transfer.id, '6fa459ea-ee8a-3ca4-894e-db77e160355e');
      expect(transfer.batchId, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(transfer.username, 'MusicLover42');
      expect(transfer.direction, TransferDirection.download);
      expect(transfer.category, TransferCategory.inProgress);
      expect(transfer.progress, 0.5);
      expect(transfer.percentComplete, 50.0);
      expect(transfer.bytesRemaining, 17500000);
      expect(transfer.remainingTime?.inSeconds, 10);
      expect(transfer.fileBaseName, '01 - One More Time.flac');
      expect(transfer.isTerminal, isFalse);
      expect(transfer.canCancel, isTrue);
      expect(transfer.canRetry, isFalse);
    });

    test('SlskdTransfer completed and failed states', () {
      final completed = SlskdTransfer.fromJson({
        'id': '1',
        'username': 'u1',
        'direction': 'Download',
        'filename': 'test.mp3',
        'size': 1000,
        'state': 'Completed, Succeeded',
        'requestedAt': '2026-10-24T12:00:00Z',
        'bytesTransferred': 1000,
      });

      expect(completed.category, TransferCategory.completed);
      expect(completed.isTerminal, isTrue);
      expect(completed.canCancel, isFalse);
      expect(completed.canRetry, isFalse);

      final failed = SlskdTransfer.fromJson({
        'id': '2',
        'username': 'u1',
        'direction': 'Download',
        'filename': 'test.mp3',
        'size': 1000,
        'state': 'Completed, Errored',
        'requestedAt': '2026-10-24T12:00:00Z',
        'bytesTransferred': 200,
      });

      expect(failed.category, TransferCategory.failed);
      expect(failed.isTerminal, isTrue);
      expect(failed.canRetry, isTrue);

      final queued = SlskdTransfer.fromJson({
        'id': '3',
        'username': 'u1',
        'direction': 'Upload',
        'filename': 'test.mp3',
        'size': 1000,
        'state': 'Queued, Remotely',
        'requestedAt': '2026-10-24T12:00:00Z',
      });

      expect(queued.direction, TransferDirection.upload);
      expect(queued.category, TransferCategory.queued);
      expect(queued.canCancel, isTrue);
      expect(queued.canRetry, isFalse);
    });

    test('SlskdUserTransfers & DirectoryTransfers tree hierarchy', () {
      final payload = {
        'username': 'audiophile',
        'directories': [
          {
            'directory': 'FLAC/Radiohead/Kid A',
            'fileCount': 2,
            'files': [
              {
                'id': 'f1',
                'username': 'audiophile',
                'direction': 'Download',
                'filename': 'FLAC/Radiohead/Kid A/01 Everything.flac',
                'size': 20000000,
                'bytesTransferred': 10000000,
                'averageSpeed': 1000000.0,
                'state': 'InProgress',
                'requestedAt': '2026-10-24T12:00:00Z',
              },
              {
                'id': 'f2',
                'username': 'audiophile',
                'direction': 'Download',
                'filename': 'FLAC/Radiohead/Kid A/02 Kid A.flac',
                'size': 20000000,
                'bytesTransferred': 5000000,
                'averageSpeed': 500000.0,
                'state': 'InProgress',
                'requestedAt': '2026-10-24T12:00:00Z',
              },
            ],
          },
        ],
      };

      final userTransfers = SlskdUserTransfers.fromJson(payload);
      expect(userTransfers.username, 'audiophile');
      expect(userTransfers.totalFiles, 2);
      expect(userTransfers.totalBytes, 40000000);
      expect(userTransfers.transferredBytes, 15000000);
      expect(userTransfers.averageSpeed, 1500000.0);
    });

    test('EnqueueDownloadBatchRequest serialization', () {
      const request = EnqueueDownloadBatchRequest(
        username: 'peer1',
        files: [
          EnqueueDownloadBatchItem(filename: 'a.mp3', size: 5000),
          EnqueueDownloadBatchItem(filename: 'b.mp3', size: 6000),
        ],
        options: EnqueueDownloadBatchOptions(destination: 'Music/Albums'),
      );

      final json = request.toJson();
      expect(json['username'], 'peer1');
      expect((json['files'] as List).length, 2);
      expect((json['options'] as Map)['destination'], 'Music/Albums');
    });
  });

  group('Slskd Search Models', () {
    test('SlskdSearch and SearchFile parsing', () {
      final searchJson = {
        'id': 's-123',
        'searchText': 'Aphex Twin',
        'state': 'Completed',
        'isComplete': true,
        'fileCount': 150,
        'lockedFileCount': 5,
        'responseCount': 12,
        'startedAt': '2026-10-24T12:00:00Z',
      };

      final search = SlskdSearch.fromJson(searchJson);
      expect(search.id, 's-123');
      expect(search.searchText, 'Aphex Twin');
      expect(search.isComplete, isTrue);
      expect(search.responseCount, 12);

      final fileJson = {
        'filename': 'Music\\Aphex Twin\\Selected Ambient\\01 Xtal.mp3',
        'size': 11200000,
        'extension': 'mp3',
        'bitRate': 320,
        'sampleRate': 44100,
        'length': 294,
        'isVariableBitRate': false,
        'isLocked': false,
      };

      final file = SlskdSearchFile.fromJson(fileJson);
      expect(file.trackTitle, '01 Xtal.mp3');
      expect(file.albumDirectory, 'Music\\Aphex Twin\\Selected Ambient');
      expect(file.formattedDuration, '4:54');
      expect(file.qualityBadge, 'MP3 320k');
    });

    test('SlskdSearchFile FLAC qualityBadge', () {
      final flac = SlskdSearchFile.fromJson({
        'filename': 'track.flac',
        'size': 45000000,
        'extension': 'flac',
        'bitDepth': 24,
        'sampleRate': 96000,
        'length': 360,
      });

      expect(flac.qualityBadge, 'FLAC 24-bit');
      expect(flac.formattedDuration, '6:00');
    });

    test('SlskdSearch isErrored from a failed search', () {
      // What slskd stores for a search started while it is not logged in to
      // Soulseek: complete, with no responses, but not an empty result.
      final errored = SlskdSearch.fromJson({
        'id': 'e1',
        'searchText': 'daft punk',
        'state': 'Completed, Errored',
        'isComplete': true,
      });
      final succeeded = SlskdSearch.fromJson({
        'id': 's1',
        'searchText': 'daft punk',
        'state': 'Completed, Succeeded',
        'isComplete': true,
      });

      expect(errored.isErrored, isTrue);
      expect(succeeded.isErrored, isFalse);
    });
  });

  group('Slskd Browse Models', () {
    test('SlskdDirectory and UserInfo parsing', () {
      final dir = SlskdDirectory.fromJson({
        'name': 'Music/Miles Davis/Kind of Blue',
        'files': [
          {
            'filename': 'Music/Miles Davis/Kind of Blue/01 So What.flac',
            'size': 60000000,
            'extension': 'flac',
          },
        ],
      });

      expect(dir.directoryBaseName, 'Kind of Blue');
      expect(dir.files.length, 1);
      expect(dir.totalSize, 60000000);

      final userInfo = SlskdUserInfo.fromJson({
        'description': 'Sharing jazz and electronics. Enjoy!',
        'hasFreeUploadSlot': true,
        'queueLength': 0,
        'uploadSlots': 3,
      });

      expect(userInfo.hasFreeUploadSlot, isTrue);
      expect(userInfo.description, contains('Sharing jazz'));
      expect(userInfo.uploadSlots, 3);
    });

    test('SlskdUserPresence parsing', () {
      final onlineUser = SlskdUserPresence.fromJson({
        'username': 'jazzfan',
        'status': 2,
        'averageSpeed': 5000000,
        'countryCode': 'DE',
        'fileCount': 12000,
      });

      expect(onlineUser.isOnline, isTrue);
      expect(onlineUser.statusLabel, 'Online');
      expect(onlineUser.countryCode, 'DE');
      expect(onlineUser.fileCount, 12000);
    });
  });

  group('Slskd Community Models', () {
    test('SlskdRoom and SlskdRoomMessage', () {
      final room = SlskdRoom.fromJson({
        'name': 'electronic',
        'isPrivate': false,
        'operators': ['mod1', 'mod2'],
        'users': [
          {'username': 'u1', 'status': 2},
          {'username': 'u2', 'status': 1},
        ],
      });

      expect(room.name, 'electronic');
      expect(room.userCount, 2);
      expect(room.operators.length, 2);

      final msg = SlskdRoomMessage.fromJson({
        'timestamp': '2026-10-24T12:30:00Z',
        'username': 'synth_head',
        'message': 'Hello everyone!',
        'roomName': 'electronic',
        'self': true,
      });

      expect(msg.username, 'synth_head');
      expect(msg.message, 'Hello everyone!');
      expect(msg.self, isTrue);
    });

    test('SlskdConversation and SlskdPrivateMessage', () {
      final conv = SlskdConversation.fromJson({
        'username': 'bob',
        'isActive': true,
        'unAcknowledgedMessageCount': 1,
        'messages': [
          {
            'id': 101,
            'username': 'bob',
            'timestamp': '2026-10-24T12:00:00Z',
            'direction': 'In',
            'message': 'Hey, thanks for the files!',
          },
        ],
      });

      expect(conv.username, 'bob');
      expect(conv.hasUnAcknowledgedMessages, isTrue);
      expect(conv.lastMessage?.message, 'Hey, thanks for the files!');
      expect(conv.lastMessage?.isInbound, isTrue);
    });
  });

  group('Slskd System Models', () {
    test('SlskdApplicationState and ServerStatus', () {
      final appState = SlskdApplicationState.fromJson({
        'version': {
          'current': '0.20.0',
          'full': '0.20.0-master+abc',
        },
        'server': {
          'address': 'vps.slsknet.org',
          'state': 'Connected, LoggedIn',
          'isConnected': true,
          'isLoggedIn': true,
        },
        'user': {
          'username': 'myuser',
          'privileges': {'isPrivileged': true, 'privilegesRemaining': 30},
          'statistics': {'fileCount': 5000, 'averageSpeed': 2000000},
        },
        'shares': {
          'scanning': false,
          'directories': 120,
          'files': 5000,
        },
      });

      expect(appState.version.current, '0.20.0');
      expect(appState.server.isConnected, isTrue);
      expect(appState.server.isLoggedIn, isTrue);
      expect(appState.user.isPrivileged, isTrue);
      expect(appState.user.privilegesRemaining, 30);
      expect(appState.shares.files, 5000);
    });

    test('SlskdLogRecord parsing and severity helpers', () {
      final log = SlskdLogRecord.fromJson({
        'timestamp': '2026-10-24T12:00:00Z',
        'level': 'Error',
        'context': 'SoulseekClient',
        'message': 'Connection reset by peer',
      });

      expect(log.isError, isTrue);
      expect(log.isWarning, isFalse);
      expect(log.context, 'SoulseekClient');
      expect(log.message, 'Connection reset by peer');
    });

    test('SlskdBatch and EnqueueDownloadBatchResponse parsing', () {
      final batchResp = EnqueueDownloadBatchResponse.fromJson({
        'batch': {
          'id': 'b1',
          'searchId': 's1',
          'username': 'peerA',
          'direction': 'Download',
          'createdAt': '2026-10-24T12:00:00Z',
          'transfers': [
            {
              'id': 't1',
              'username': 'peerA',
              'direction': 'Download',
              'filename': 'a.mp3',
              'size': 100,
              'state': 'InProgress',
              'requestedAt': '2026-10-24T12:00:00Z',
            }
          ],
          'options': {'destination': '/music', 'externalId': 'ext1'},
        },
        'failures': [
          {'filename': 'b.mp3', 'message': 'File not shared'},
        ],
      });

      expect(batchResp.batch?.id, 'b1');
      expect(batchResp.batch?.transfers.length, 1);
      expect(batchResp.batch?.options.destination, '/music');
      expect(batchResp.failures.length, 1);
      expect(batchResp.failures.first.filename, 'b.mp3');
    });

    test('SlskdUserInfo Base64 picture and SlskdUserStatus parsing', () {
      // "SGVsbG8=" is base64 for [72, 101, 108, 108, 111]
      final info = SlskdUserInfo.fromJson({
        'description': 'Hello world',
        'hasPicture': true,
        'picture': 'SGVsbG8=',
        'queueLength': 3,
        'uploadSlots': 1,
      });

      expect(info.picture, [72, 101, 108, 108, 111]);
      expect(info.queueLength, 3);

      final status = SlskdUserStatus.fromJson({
        'isPrivileged': true,
        'presence': 'Online',
      });
      expect(status.isPrivileged, isTrue);
      expect(status.isOnline, isTrue);
      expect(status.isAway, isFalse);
    });

    test('MessageDirection numeric 0 (Out) and 1 (In) parsing', () {
      expect(MessageDirection.fromJson(0), MessageDirection.outbound);
      expect(MessageDirection.fromJson(1), MessageDirection.inbound);
      expect(MessageDirection.fromJson('Out'), MessageDirection.outbound);
      expect(MessageDirection.fromJson('In'), MessageDirection.inbound);

      final roomInfo = SlskdRoomInfo.fromJson({
        'name': 'electronic',
        'userCount': 45,
        'isPrivate': false,
      });
      expect(roomInfo.name, 'electronic');
      expect(roomInfo.userCount, 45);
    });

    test('SlskdSearch heuristic isComplete fallback when isComplete key is omitted', () {
      final searchComplete = SlskdSearch.fromJson({
        'id': 's1',
        'searchText': 'daft punk',
        'state': 'Completed, Succeeded',
        'startedAt': '2026-10-24T12:00:00Z',
      });
      expect(searchComplete.isComplete, isTrue);

      final searchActive = SlskdSearch.fromJson({
        'id': 's2',
        'searchText': 'justice',
        'state': 'Requested',
        'startedAt': '2026-10-24T12:00:00Z',
      });
      expect(searchActive.isComplete, isFalse);
    });

    test('SlskdApplicationState connectionWatchdog and SlskdLocalShare properties', () {
      final appState = SlskdApplicationState.fromJson({
        'version': {'current': '0.20.0'},
        'server': {'address': 'vps.slsknet.org', 'state': 'Connected'},
        'user': {'username': 'test'},
        'shares': <String, dynamic>{},
        'pendingReconnect': true,
        'connectionWatchdog': {
          'isEnabled': true,
          'isAttemptingConnection': true,
        },
      });

      expect(appState.pendingReconnect, isTrue);
      expect(appState.connectionWatchdog?.isEnabled, isTrue);
      expect(appState.connectionWatchdog?.isAttemptingConnection, isTrue);

      final share = SlskdLocalShare.fromJson({
        'id': 'sh1',
        'alias': 'Lossless',
        'localPath': '/music/flac',
        'remotePath': 'FLAC\\',
        'raw': '[Lossless]/music/flac',
        'isExcluded': false,
        'directories': 15,
        'files': 320,
      });

      expect(share.name, 'Lossless');
      expect(share.path, '/music/flac');
      expect(share.remotePath, 'FLAC\\');
      expect(share.directories, 15);
      expect(share.files, 320);
    });

    test('SlskdSearchFormatFilter matchesExtension tests', () {
      expect(SlskdSearchFormatFilter.all.matchesExtension('flac'), isTrue);
      expect(SlskdSearchFormatFilter.all.matchesExtension('mp3'), isTrue);
      expect(SlskdSearchFormatFilter.flacOnly.matchesExtension('FLAC'), isTrue);
      expect(SlskdSearchFormatFilter.flacOnly.matchesExtension('mp3'), isFalse);
      expect(SlskdSearchFormatFilter.mp3Only.matchesExtension('mp3'), isTrue);
      expect(SlskdSearchFormatFilter.oggOnly.matchesExtension('ogg'), isTrue);
      expect(SlskdSearchFormatFilter.wavOnly.matchesExtension('WAV'), isTrue);
      expect(SlskdSearchFormatFilter.aacOnly.matchesExtension('aac'), isTrue);
      expect(SlskdSearchFormatFilter.m4aOnly.matchesExtension('M4A'), isTrue);
      expect(SlskdSearchFormatFilter.opusOnly.matchesExtension('opus'), isTrue);
    });

    test('SlskdServerStatus disconnected and disconnecting heuristic tests', () {
      final disconnected = SlskdServerStatus.fromJson({
        'address': 'vps.slsknet.org',
        'state': 'Disconnected',
      });
      expect(disconnected.isConnected, isFalse);
      expect(disconnected.isConnecting, isFalse);
      expect(disconnected.isTransitioning, isFalse);

      final disconnecting = SlskdServerStatus.fromJson({
        'address': 'vps.slsknet.org',
        'state': 'Disconnecting',
      });
      expect(disconnecting.isConnected, isFalse);
      expect(disconnecting.isConnecting, isFalse);
      expect(disconnecting.isTransitioning, isTrue);

      final connecting = SlskdServerStatus.fromJson({
        'address': 'vps.slsknet.org',
        'state': 'Connecting',
      });
      expect(connecting.isConnected, isFalse);
      expect(connecting.isConnecting, isTrue);
      expect(connecting.isTransitioning, isTrue);
    });

    test('SlskdTransfer compound failure state', () {
      final transfer = SlskdTransfer.fromJson({
        'id': '99',
        'username': 'u1',
        'direction': 'Download',
        'filename': 'Music/album/song.mp3',
        'size': 5000,
        'state': 'Completed, Failed',
      });
      expect(transfer.category, TransferCategory.failed);
      expect(transfer.isTerminal, isTrue);
    });

    test('SlskdSearch Errored state completion heuristic', () {
      final search = SlskdSearch.fromJson({
        'id': 's1',
        'searchText': 'test query',
        'state': 'Errored',
      });
      expect(search.isComplete, isTrue);
    });

    test('SlskdSearchResponse lockedFiles defaultLocked flag', () {
      final response = SlskdSearchResponse.fromJson({
        'username': 'locked_user',
        'fileCount': 1,
        'lockedFileCount': 1,
        'hasFreeUploadSlot': false,
        'queueLength': 0,
        'uploadSpeed': 0,
        'token': 1,
        'lockedFiles': [
          {
            'filename': 'secret/vault.flac',
            'size': 12345,
            'extension': 'flac',
          },
        ],
      });
      expect(response.lockedFiles.length, 1);
      expect(response.lockedFiles.first.isLocked, isTrue);
    });

    test('SlskdAlbumGroup qualityBadge derives from audio format extension', () {
      const album = SlskdAlbumGroup(
        albumDirectory: 'Music/Artist/Album',
        username: 'user1',
        hasFreeUploadSlot: true,
        queueLength: 0,
        uploadSpeed: 1000,
        files: [
          SlskdSearchFile(
            filename: 'song1.m4a',
            size: 5000,
            extension: 'm4a',
            bitRate: 256,
          ),
          SlskdSearchFile(
            filename: 'song2.m4a',
            size: 5000,
            extension: 'm4a',
            bitRate: 320,
          ),
        ],
      );
      expect(album.qualityBadge, 'M4A 320k');
    });
  });

  group('BrowseNode', () {
    test('locks a subfolder listed before its locked parent', () {
      final BrowseNode root = BrowseNode.buildTree(const <SlskdDirectory>[
        SlskdDirectory(
          name: r'Vault\Inner',
          files: <SlskdSearchFile>[
            SlskdSearchFile(filename: r'Vault\Inner\a.flac', size: 1, extension: 'flac'),
          ],
        ),
        SlskdDirectory(name: 'Vault', isLocked: true),
        SlskdDirectory(
          name: 'Open',
          files: <SlskdSearchFile>[
            SlskdSearchFile(filename: r'Open\b.flac', size: 1, extension: 'flac'),
            SlskdSearchFile(filename: r'Open\c.flac', size: 1, extension: 'flac', isLocked: true),
          ],
        ),
      ]);

      expect(root.subfolders['Vault']!.subfolders['Inner']!.isLocked, isTrue);
      expect(
        root.getDownloadableFilesRecursive().map((SlskdSearchFile f) => f.filename),
        <String>[r'Open\b.flac'],
      );
    });
  });

  group('Transfer live speed', () {
    SlskdTransfer transfer(String state, double speed) => SlskdTransfer(
          id: state,
          username: 'peer',
          direction: TransferDirection.download,
          filename: 'a.flac',
          size: 100,
          state: state,
          requestedAt: DateTime(2026),
          averageSpeed: speed,
        );

    test('counts only transfers that are running', () {
      expect(transfer('Completed, Succeeded', 5000).liveSpeed, 0);
      expect(transfer('Completed, Errored', 5000).liveSpeed, 0);
      expect(transfer('InProgress', 1000).liveSpeed, 1000);
      expect(transfer('InProgress', double.nan).liveSpeed, 0);

      final SlskdUserTransfers user = SlskdUserTransfers(
        username: 'peer',
        directories: <SlskdDirectoryTransfers>[
          SlskdDirectoryTransfers(
            directory: 'Album',
            fileCount: 2,
            files: <SlskdTransfer>[
              transfer('Completed, Succeeded', 5000),
              transfer('InProgress', 1000),
            ],
          ),
        ],
      );
      expect(user.liveSpeed, 1000);
    });
  });
}
