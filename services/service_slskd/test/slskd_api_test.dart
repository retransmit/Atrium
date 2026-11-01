import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';

void main() {
  group('SlskdApi Client Unit Tests', () {
    late Dio dio;
    late SlskdApi api;
    late String lastPath;
    late String lastMethod;
    late Map<String, dynamic>? lastQueryParams;
    late dynamic lastData;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:5030/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastPath = options.path;
            lastMethod = options.method;
            lastQueryParams = options.queryParameters;
            lastData = options.data;

            // Route mock responses based on path and method
            if (options.path == 'api/v0/application') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'version': {'current': '0.20.0'},
                    'server': {'address': 'vps.slsknet.org', 'state': 'Connected'},
                    'user': {'username': 'testUser'},
                    'shares': {'directories': 10, 'files': 500},
                  },
                ),
              );
            }

            if (options.path == 'api/v0/transfers/downloads') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'username': 'peerA',
                      'directories': [
                        {
                          'directory': 'Rock/Album1',
                          'fileCount': 1,
                          'files': [
                            {
                              'id': 'dl1',
                              'username': 'peerA',
                              'direction': 'Download',
                              'filename': 'Rock/Album1/track1.mp3',
                              'size': 5000000,
                              'state': 'InProgress',
                              'requestedAt': '2026-10-24T12:00:00Z',
                            }
                          ],
                        }
                      ],
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/transfers/uploads') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'username': 'peerB',
                      'directories': [
                        {
                          'directory': 'Electronic/Album2',
                          'fileCount': 1,
                          'files': [
                            {
                              'id': 'ul1',
                              'username': 'peerB',
                              'direction': 'Upload',
                              'filename': 'Electronic/Album2/track2.flac',
                              'size': 25000000,
                              'state': 'Completed, Succeeded',
                              'requestedAt': '2026-10-24T12:00:00Z',
                            }
                          ],
                        }
                      ],
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/transfers/downloads/peerA/dl1') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'dl1',
                    'username': 'peerA',
                    'direction': 'Download',
                    'filename': 'Rock/Album1/track1.mp3',
                    'size': 5000000,
                    'state': 'InProgress',
                    'requestedAt': '2026-10-24T12:00:00Z',
                  },
                ),
              );
            }

            if (options.path == 'api/v0/transfers/downloads/batches') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'batch': {
                      'id': 'batch123',
                      'username': 'peerA',
                      'direction': 'Download',
                      'createdAt': '2026-10-24T12:00:00Z',
                      'transfers': <Map<String, dynamic>>[],
                    },
                    'failures': <Map<String, dynamic>>[],
                  },
                ),
              );
            }

            if (options.path == 'api/v0/searches' && options.method == 'POST') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 'search123',
                    'searchText': 'daft punk',
                    'state': 'Requested',
                    'startedAt': '2026-10-24T12:00:00Z',
                  },
                ),
              );
            }

            if (options.path == 'api/v0/searches' && options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'search123',
                      'searchText': 'daft punk',
                      'state': 'Completed',
                      'fileCount': 150,
                      'startedAt': '2026-10-24T12:00:00Z',
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/searches/search123/responses') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'username': 'audioGod',
                      'fileCount': 1,
                      'files': [
                        {
                          'filename': 'Daft Punk\\Discovery\\01 One More Time.flac',
                          'size': 35000000,
                          'extension': 'flac',
                          'bitDepth': 24,
                          'sampleRate': 96000,
                        }
                      ],
                    }
                  ],
                ),
              );
            }

            // slskd answers 404 when the peer is offline.
            if (options.path == 'api/v0/users/offlinePeer/browse') {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 404,
                    data: 'User offlinePeer appears to be offline',
                  ),
                ),
              );
            }

            if (options.path == 'api/v0/users/peerA/browse') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'name': 'FLAC\\Radiohead',
                      'files': [
                        {
                          'filename': '01 15 Step.flac',
                          'size': 30000000,
                          'extension': 'flac',
                        }
                      ],
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/users/peerA/info') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'description': 'Sharing FLAC lossless music only',
                    'hasFreeUploadSlot': true,
                    'uploadSlots': 2,
                    'queueLength': 0,
                  },
                ),
              );
            }

            if (options.path == 'api/v0/rooms/available') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'name': 'electronic',
                      'userCount': 50,
                      'isPrivate': false,
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/rooms/joined') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: ['electronic', 'lossless'],
                ),
              );
            }

            if (options.path == 'api/v0/conversations') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 1,
                      'username': 'alice',
                      'isActive': true,
                      'unAcknowledgedMessageCount': 2,
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/conversations/alice/messages') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 101,
                      'username': 'alice',
                      'timestamp': '2026-10-24T12:00:00Z',
                      'direction': 1, // Inbound
                      'message': 'Hey, nice share!',
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/shares') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'localhost': [
                      {
                        'id': 'sh1',
                        'alias': 'Music',
                        'localPath': '/data/music',
                        'directories': 120,
                        'files': 3500,
                      }
                    ]
                  },
                ),
              );
            }

            if (options.path == 'api/v0/logs/live' || options.path == 'api/v0/logs') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'timestamp': '2026-10-24T12:00:00Z',
                      'level': 'Information',
                      'message': 'Soulseek client connected',
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/transfers/downloads/peerA/dl1/position') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: 3,
                ),
              );
            }

            if (options.path == 'api/v0/users/peerA/browse/status') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: 0.75,
                ),
              );
            }

            if (options.path == 'api/v0/users/peerA/endpoint') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '192.168.1.50:2234',
                ),
              );
            }

            if (options.path == 'api/v0/application/version/latest') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'current': '0.6.4',
                    'latest': '0.6.5',
                    'isUpdateAvailable': true,
                  },
                ),
              );
            }

            if (options.path == 'api/v0/server' && options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'address': 'vps.slsknet.org',
                    'port': 2242,
                    'state': 'Connected',
                  },
                ),
              );
            }

            if (options.path == 'api/v0/shares/sh1') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'sh1',
                    'alias': 'Music',
                    'localPath': '/data/music',
                    'directories': 120,
                    'files': 3500,
                  },
                ),
              );
            }

            if (options.path == 'api/v0/shares/contents' ||
                options.path == 'api/v0/shares/sh1/contents') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'name': 'Electronic/Aphex Twin',
                      'files': [
                        {
                          'filename': '01 Xtal.mp3',
                          'size': 8500000,
                          'extension': 'mp3',
                          'bitRate': 320,
                        }
                      ],
                    }
                  ],
                ),
              );
            }

            if (options.path.startsWith('api/v0/files/downloads/directories') ||
                options.path.startsWith('api/v0/files/incomplete/directories')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'name': 'downloads',
                    'fullName': '/data/downloads',
                    'files': [
                      {
                        'name': 'track1.flac',
                        'fullName': '/data/downloads/track1.flac',
                        'length': 45000000,
                      }
                    ],
                    'directories': [
                      {
                        'name': 'AlbumA',
                        'fullName': '/data/downloads/AlbumA',
                        'files': <dynamic>[],
                        'directories': <dynamic>[],
                      }
                    ],
                  },
                ),
              );
            }

            if (options.path == 'api/v0/logs/files') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'name': 'slskd-20261028.log',
                      'fullName': '/app/logs/slskd-20261028.log',
                      'length': 124500,
                    }
                  ],
                ),
              );
            }

            if (options.path.startsWith('api/v0/logs/files/')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '[2026-10-28 12:00:00 INF] Daemon ready\n[2026-10-28 12:00:01 INF] Shares indexed: 500 files',
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/summary') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'Download': {
                      'Completed, Succeeded': {
                        'totalBytes': 1200000000,
                        'count': 42,
                        'averageSpeed': 1500000.0,
                      }
                    }
                  },
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/histogram') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    '2026-10-28T00:00:00Z': {
                      'Download': {
                        'Completed': {'totalBytes': 500000000, 'count': 10}
                      }
                    }
                  },
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/leaderboard') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'username': 'peerLeader',
                      'totalBytes': 5000000000,
                      'count': 120,
                      'distinctUsers': 1,
                      'averageSpeed': 2400000.0,
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/users/peerA') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'Download': {
                      'summary': {
                        'Completed': {'totalBytes': 80000000, 'count': 5}
                      },
                      'statistics': {
                        'total': 5,
                        'successful': 5,
                        'errored': 0,
                        'cancelled': 0,
                      }
                    }
                  },
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/exceptions') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'ex1',
                      'username': 'slowPeer',
                      'direction': 'Download',
                      'filename': 'track.flac',
                      'exception': 'Connection timed out',
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/exceptions/pareto') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'exception': 'Cancelled by remote user',
                      'count': 14,
                      'distinctUsers': 6,
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/reports/transfers/directories') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'directory': 'Lossless/Radiohead',
                      'count': 88,
                      'distinctUsers': 12,
                    }
                  ],
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/metrics/kpis') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'process_working_set_bytes': {
                      'name': 'process_working_set_bytes',
                      'type': 'gauge',
                      'samples': [
                        {'value': 157286400.0}
                      ],
                    },
                    'dotnet_total_memory_bytes': {
                      'name': 'dotnet_total_memory_bytes',
                      'type': 'gauge',
                      'samples': [
                        {'value': 52428800.0}
                      ],
                    }
                  },
                ),
              );
            }

            if (options.path == 'api/v0/telemetry/metrics') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'slskd_searches_total': {
                      'name': 'slskd_searches_total',
                      'type': 'counter',
                      'sum': 42.0,
                    }
                  },
                ),
              );
            }

            if (options.path == 'api/v0/options') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.method == 'PATCH'
                      ? {'soulseek': {'listenPort': 50301}}
                      : {'soulseek': {'listenPort': 50300}, 'shares': {'directories': ['/music']}},
                ),
              );
            }

            if (options.path == 'api/v0/options/startup') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'soulseek': {'listenPort': 50300}},
                ),
              );
            }

            if (options.path == 'api/v0/options/yaml/location') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '/app/slskd.yml',
                ),
              );
            }

            if (options.path == 'api/v0/options/yaml') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.method == 'GET'
                      ? 'soulseek:\n  listen_port: 50300\n'
                      : null,
                ),
              );
            }

            if (options.path == 'api/v0/options/yaml/validate') {
              final bodyStr = options.data?.toString() ?? '';
              final errorMsg = bodyStr.contains('invalid')
                  ? 'Invalid YAML syntax: unexpected key'
                  : null;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: errorMsg,
                ),
              );
            }

            if (options.path == 'api/v0/debug/transfers') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'active': <dynamic>[],
                    'queued': <dynamic>[],
                  },
                ),
              );
            }

            // Default 200 / 204 handler
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: options.method == 'DELETE' ? 204 : 200,
              ),
            );
          },
        ),
      );
      api = SlskdApi(dio);
    });

    test('getApplicationState invokes GET api/v0/application and parses model', () async {
      final state = await api.getApplicationState();
      expect(lastPath, 'api/v0/application');
      expect(lastMethod, 'GET');
      expect(state.version.current, '0.20.0');
      expect(state.server.address, 'vps.slsknet.org');
      expect(state.user.username, 'testUser');
    });

    test('getDownloads and getUploads query proper endpoints with parameters', () async {
      final downloads = await api.getDownloads(includeRemoved: true);
      expect(lastPath, 'api/v0/transfers/downloads');
      expect(lastMethod, 'GET');
      expect(lastQueryParams?['includeRemoved'], isTrue);
      expect(downloads.length, 1);
      expect(downloads.first.username, 'peerA');

      final uploads = await api.getUploads();
      expect(lastPath, 'api/v0/transfers/uploads');
      expect(lastMethod, 'GET');
      expect(uploads.first.username, 'peerB');
      expect(uploads.first.directories.first.files.first.category, TransferCategory.completed);
    });



    test('cancelDownload and clearCompletedDownloads invoke DELETE endpoints', () async {
      await api.cancelDownload('peerA', 'dl1', remove: true);
      expect(lastPath, 'api/v0/transfers/downloads/peerA/dl1');
      expect(lastMethod, 'DELETE');
      expect(lastQueryParams?['remove'], isTrue);

      await api.clearCompletedDownloads();
      expect(lastPath, 'api/v0/transfers/downloads/all/completed');
      expect(lastMethod, 'DELETE');

      final pos = await api.getPlaceInQueue('peerA', 'dl1');
      expect(lastPath, 'api/v0/transfers/downloads/peerA/dl1/position');
      expect(pos, 3);

      await api.enqueueDownloads('peerA', [
        const QueueDownloadRequest(filename: 'a.mp3', size: 100),
      ]);
      expect(lastPath, 'api/v0/transfers/downloads/batches');
      expect(lastMethod, 'POST');
    });

    test('enqueueBatch serializes request and returns EnqueueDownloadBatchResponse', () async {
      const req = EnqueueDownloadBatchRequest(
        username: 'peerA',
        files: [
          EnqueueDownloadBatchItem(filename: 'Rock/a.mp3', size: 1000),
        ],
        options: EnqueueDownloadBatchOptions(destination: 'Rock'),
      );
      final resp = await api.enqueueBatch(req);
      expect(lastPath, 'api/v0/transfers/downloads/batches');
      expect(lastMethod, 'POST');
      expect((lastData as Map<String, dynamic>)['username'], 'peerA');
      expect(resp.batch?.id, 'batch123');
    });

    test('Search endpoints: initiate, list, get responses, delete, stop', () async {
      final search = await api.initiateSearch(
        const SlskdSearchRequest(searchText: 'daft punk'),
      );
      expect(lastPath, 'api/v0/searches');
      expect(lastMethod, 'POST');
      expect(search.id, 'search123');

      final searches = await api.getSearches();
      expect(lastPath, 'api/v0/searches');
      expect(lastMethod, 'GET');
      expect(searches.first.fileCount, 150);

      final responses = await api.getSearchResponses('search123');
      expect(lastPath, 'api/v0/searches/search123/responses');
      expect(responses.first.username, 'audioGod');
      expect(responses.first.files.first.qualityBadge, 'FLAC 24-bit');

      await api.stopSearch('search123');
      expect(lastPath, 'api/v0/searches/search123');
      expect(lastMethod, 'PUT');

      await api.deleteSearch('search123');
      expect(lastPath, 'api/v0/searches/search123');
      expect(lastMethod, 'DELETE');
    });

    test('Browse & User endpoints: browseUser, getUserInfo, browseStatus', () async {
      final dirs = await api.browseUser('peerA');
      expect(lastPath, 'api/v0/users/peerA/browse');
      expect(dirs.first.name, 'FLAC\\Radiohead');

      // An offline peer is an error, not an empty share.
      await expectLater(
        api.browseUser('offlinePeer'),
        throwsA(isA<DioException>()),
      );

      final info = await api.getUserInfo('peerA');
      expect(lastPath, 'api/v0/users/peerA/info');
      expect(info.description, 'Sharing FLAC lossless music only');
      expect(info.hasFreeUploadSlot, isTrue);

      final status = await api.getBrowseStatus('peerA');
      expect(lastPath, 'api/v0/users/peerA/browse/status');
      expect(status, 0.75);

      final endpoint = await api.getUserEndpoint('peerA');
      expect(lastPath, 'api/v0/users/peerA/endpoint');
      expect(endpoint?.address, '192.168.1.50');
      expect(endpoint?.port, 2234);
    });

    test('Community endpoints: rooms and conversations', () async {
      final rooms = await api.getAvailableRooms();
      expect(lastPath, 'api/v0/rooms/available');
      expect(rooms.first.name, 'electronic');
      expect(rooms.first.userCount, 50);

      final joined = await api.getJoinedRoomNames();
      expect(lastPath, 'api/v0/rooms/joined');
      expect(joined, contains('electronic'));

      final convos = await api.getConversations();
      expect(lastPath, 'api/v0/conversations');
      expect(convos.first.username, 'alice');
      expect(convos.first.unAcknowledgedMessageCount, 2);

      final messages = await api.getConversationMessages('alice');
      expect(lastPath, 'api/v0/conversations/alice/messages');
      expect(messages.first.id, 101);
      expect(messages.first.direction, MessageDirection.inbound);
      expect(messages.first.isInbound, isTrue);

      await api.sendPrivateMessage('alice', 'thanks!');
      expect(lastPath, 'api/v0/conversations/alice');
      expect(lastMethod, 'POST');
      expect(lastData, jsonEncode('thanks!'));



      await api.acknowledgeAllMessages('alice');
      expect(lastPath, 'api/v0/conversations/alice');
      expect(lastMethod, 'PUT');

      await api.setRoomTicker('electronic', 'New rules: 320kbps+ only');
      expect(lastPath, 'api/v0/rooms/joined/electronic/ticker');
      expect(lastMethod, 'POST');
      expect(lastData, jsonEncode('New rules: 320kbps+ only'));

      await api.addPrivateRoomMember('lossless', 'alice');
      expect(lastPath, 'api/v0/rooms/joined/lossless/members');
      expect(lastMethod, 'POST');
      expect(lastData, jsonEncode('alice'));
    });

    test('System endpoints: server connect/disconnect, shares, logs', () async {
      await api.reconnectServer();
      expect(lastPath, 'api/v0/server');
      expect(lastMethod, 'PUT');

      await api.disconnectServer();
      expect(lastPath, 'api/v0/server');
      expect(lastMethod, 'DELETE');

      final shares = await api.getShares();
      expect(lastPath, 'api/v0/shares');
      expect(shares['localhost']?.first.name, 'Music');

      await api.scanShares();
      expect(lastPath, 'api/v0/shares');
      expect(lastMethod, 'PUT');

      final logs = await api.getLogs();
      expect(lastPath, 'api/v0/logs/live');
      expect(logs.first.level, 'Information');
      expect(logs.first.message, 'Soulseek client connected');
    });

    test('Phase 3 endpoints: host files explorer, shares contents, and historical logs', () async {
      // 1. Share contents
      final allShared = await api.getAllSharedContents();
      expect(lastPath, 'api/v0/shares/contents');
      expect(allShared.first.name, 'Electronic/Aphex Twin');
      expect(allShared.first.files.first.filename, '01 Xtal.mp3');

      final shareContents = await api.getShareContents('sh1');
      expect(lastPath, 'api/v0/shares/sh1/contents');
      expect(shareContents.first.name, 'Electronic/Aphex Twin');

      // 2. Downloads directory and file deletion
      final dlRoot = await api.getDownloadsDirectory();
      expect(lastPath, 'api/v0/files/downloads/directories');
      expect(dlRoot, isNotNull);
      expect(dlRoot!.name, 'downloads');
      expect(dlRoot.files.first.name, 'track1.flac');

      final dlSub = await api.getDownloadsDirectory(subdirectory: 'AlbumA');
      expect(dlSub, isNotNull);
      final expectedB64 = Uri.encodeComponent(base64.encode(utf8.encode('AlbumA')));
      expect(lastPath, 'api/v0/files/downloads/directories/$expectedB64');

      await api.deleteDownloadDirectory('AlbumA');
      expect(lastPath, 'api/v0/files/downloads/directories/$expectedB64');
      expect(lastMethod, 'DELETE');

      await api.deleteDownloadFile('track1.flac');
      final expectedFileB64 = Uri.encodeComponent(base64.encode(utf8.encode('track1.flac')));
      expect(lastPath, 'api/v0/files/downloads/files/$expectedFileB64');
      expect(lastMethod, 'DELETE');

      // 3. Incomplete directory and file deletion
      final incRoot = await api.getIncompleteDirectory();
      expect(lastPath, 'api/v0/files/incomplete/directories');
      expect(incRoot, isNotNull);

      await api.deleteIncompleteDirectory('IncompleteAlbum');
      final expectedIncB64 = Uri.encodeComponent(base64.encode(utf8.encode('IncompleteAlbum')));
      expect(lastPath, 'api/v0/files/incomplete/directories/$expectedIncB64');
      expect(lastMethod, 'DELETE');

      await api.deleteIncompleteFile('partial.mp3');
      final expectedIncFileB64 = Uri.encodeComponent(base64.encode(utf8.encode('partial.mp3')));
      expect(lastPath, 'api/v0/files/incomplete/files/$expectedIncFileB64');
      expect(lastMethod, 'DELETE');

      // 4. Historical logs
      final logFiles = await api.getLogFiles();
      expect(lastPath, 'api/v0/logs/files');
      expect(logFiles.first.name, 'slskd-20261028.log');

      final logContent = await api.getLogFileContent('slskd-20261028.log');
      expect(lastPath, 'api/v0/logs/files/slskd-20261028.log');
      expect(logContent, contains('Daemon ready'));
    });

    test('Phase 4 endpoints: telemetry leaderboard, pareto, directories, kpis', () async {
      // 1. Leaderboard
      final leaderboard = await api.getTransferLeaderboard(direction: 'Download');
      expect(lastPath, 'api/v0/telemetry/reports/transfers/leaderboard');
      expect(lastQueryParams?['direction'], 'Download');
      expect(lastQueryParams?['sortBy'], 'Count');
      expect(lastQueryParams?['sortOrder'], 'DESC');
      expect(leaderboard.first.username, 'peerLeader');
      expect(leaderboard.first.totalBytes, 5000000000);

      // 2. Pareto
      final pareto = await api.getTransferExceptionsPareto(direction: 'Download');
      expect(lastPath, 'api/v0/telemetry/reports/transfers/exceptions/pareto');
      expect(pareto.first.exception, 'Cancelled by remote user');
      expect(pareto.first.count, 14);

      // 3. Directories frequency
      final dirs = await api.getTransferDirectories();
      expect(lastPath, 'api/v0/telemetry/reports/transfers/directories');
      expect(dirs.first.directory, 'Lossless/Radiohead');
      expect(dirs.first.count, 88);

      // 4. Prometheus KPIs
      final kpis = await api.getPrometheusKpis();
      expect(lastPath, 'api/v0/telemetry/metrics/kpis');
      expect(kpis['process_working_set_bytes']?.samples.first.value, 157286400.0);
    });

    test('Phase 5 & 6 endpoints: options, gc, loopback, debug', () async {
      // 1. Options
      final options = await api.getOptions();
      expect(lastPath, 'api/v0/options');
      expect(lastMethod, 'GET');
      expect(options['soulseek'], isNotNull);

      // 2. Diagnostics & GC & Loopback
      await api.collectGarbage();
      expect(lastPath, 'api/v0/application/gc');
      expect(lastMethod, 'POST');

      await api.loopbackTest({'ping': 'pong'});
      expect(lastPath, 'api/v0/application/loopback');
      expect(lastMethod, 'POST');

      final debugTransfers = await api.getDebugTransfers();
      expect(lastPath, 'api/v0/debug/transfers');
      expect(debugTransfers['active'], isA<List<dynamic>>());
    });
  });
}
