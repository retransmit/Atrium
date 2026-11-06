import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

SeerrUser _user(int permissions, {int id = 7}) =>
    SeerrUser(id: id, displayName: 'Kid', permissions: permissions);

/// Seerr's default for a new user: request, and report issues.
const int _plain = SeerrPermission.request | SeerrPermission.createIssues;

SeerrRequest _request({required int by, int status = 1}) => SeerrRequest(
      id: by * 10 + status,
      status: status,
      type: 'movie',
      requestedBy: SeerrUser(id: by, displayName: 'User $by'),
      media: SeerrMedia(mediaType: 'movie', tmdbId: by * 100 + status),
    );

SeerrIssue _issue({required int by}) =>
    SeerrIssue(id: 1, createdBy: SeerrUser(id: by));

void main() {
  group('SeerrUserPermissions', () {
    test('an admin may do everything', () {
      final SeerrUser admin = _user(SeerrPermission.admin);
      expect(admin.canManageRequests, isTrue);
      expect(admin.canViewAllRequests, isTrue);
      expect(admin.canRequest('tv', is4k: true), isTrue);
      expect(admin.canRequestAdvanced, isTrue);
      expect(admin.canDelete(_request(by: 3, status: 2)), isTrue);
      expect(admin.canSeeIssues, isTrue);
      expect(admin.canWorkOn(_issue(by: 3)), isTrue);
    });

    test('a plain user requests and reports, and manages nothing', () {
      final SeerrUser kid = _user(_plain);
      expect(kid.canManageRequests, isFalse);
      expect(kid.canViewAllRequests, isFalse);
      expect(kid.canRequest('movie'), isTrue);
      expect(kid.canRequest('tv'), isTrue);
      expect(kid.canRequest('movie', is4k: true), isFalse);
      expect(kid.canRequestAdvanced, isFalse);
      expect(kid.canSeeIssues, isTrue);
      expect(kid.canReportIssues, isTrue);
    });

    test('the per-type request bits allow only their own type', () {
      final SeerrUser movies = _user(SeerrPermission.requestMovie);
      expect(movies.canRequest('movie'), isTrue);
      expect(movies.canRequest('tv'), isFalse);

      final SeerrUser tv4k = _user(SeerrPermission.request4kTv);
      expect(tv4k.canRequest('tv', is4k: true), isTrue);
      expect(tv4k.canRequest('tv'), isFalse);
      expect(tv4k.canRequest('movie', is4k: true), isFalse);
    });

    test('a requester may withdraw only their own pending request', () {
      final SeerrUser kid = _user(_plain);
      expect(kid.canDelete(_request(by: 7)), isTrue);
      expect(kid.canDelete(_request(by: 7, status: 2)), isFalse);
      expect(kid.canDelete(_request(by: 3)), isFalse);
    });

    test('a reporter works only on their own issue', () {
      final SeerrUser kid = _user(_plain);
      expect(kid.canWorkOn(_issue(by: 7)), isTrue);
      expect(kid.canWorkOn(_issue(by: 3)), isFalse);
      // Viewing issues alone does not let them comment on their own.
      expect(
        _user(SeerrPermission.viewIssues).canWorkOn(_issue(by: 7)),
        isFalse,
      );
      expect(
        _user(SeerrPermission.manageIssues).canWorkOn(_issue(by: 3)),
        isTrue,
      );
    });

    test('no issue permission hides issues', () {
      expect(_user(SeerrPermission.request).canSeeIssues, isFalse);
    });

    test('reads the permissions and id auth/me answers with', () {
      final SeerrUser me = SeerrUser.fromJson(<String, dynamic>{
        'id': 7,
        'email': 'kid@example.com',
        'displayName': 'Kid',
        'permissions': 4194336,
        'userType': 3,
      });
      expect(me.id, 7);
      expect(me.permissions, _plain);
    });
  });

  group('request cards', () {
    testWidgets('a plain user sees no approve or decline, and may delete '
        'only their own pending request', (WidgetTester tester) async {
      await _pumpHome(tester, _user(_plain));

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      // Theirs has a menu with only Delete; the other user's has none.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      // The Issues tab stays, since this user may report issues.
      expect(find.text('Issues'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('a request manager keeps every action',
        (WidgetTester tester) async {
      await _pumpHome(tester, _user(SeerrPermission.manageRequests));

      expect(find.text('Approve'), findsNWidgets(2));
      expect(find.text('Decline'), findsNWidgets(2));
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      await _unmount(tester);
    });

    testWidgets('an account without issue permissions has no Issues tab',
        (WidgetTester tester) async {
      await _pumpHome(tester, _user(SeerrPermission.request));

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Issues'), findsNothing);

      await _unmount(tester);
    });
  });

  group('request sheet without server options', () {
    testWidgets('an account allowed only 4K asks for 4K',
        (WidgetTester tester) async {
      final _FakeApi api = _FakeApi(_user(SeerrPermission.request4kMovie));
      await _pumpDetail(tester, api);

      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();
      // The servers failed to load, so the sheet offers Seerr's defaults.
      expect(
        find.textContaining('Advanced options are unavailable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Request').last);
      await tester.pumpAndSettle();

      expect(api.requested, <bool>[true]);
    });

    testWidgets('an account that cannot request gets no Request button',
        (WidgetTester tester) async {
      // Opened before auth/me answered, which then says no.
      final Completer<SeerrUser> me = Completer<SeerrUser>();
      final _FakeApi api = _FakeApi(_user(0), meFuture: me.future);
      await _pumpDetail(tester, api);

      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();
      // The screen's button and the sheet's, while nobody knows better.
      final Finder buttons = find.byWidgetPredicate(
        (Widget w) =>
            w is ButtonStyleButton &&
            find
                .descendant(
                  of: find.byWidget(w),
                  matching: find.text('Request'),
                )
                .evaluate()
                .isNotEmpty,
      );
      expect(buttons, findsNWidgets(2));

      me.complete(_user(SeerrPermission.createIssues));
      await tester.pumpAndSettle();

      expect(
        find.text('This account cannot request movies in Seerr.'),
        findsOneWidget,
      );
      expect(buttons, findsNothing);
      expect(api.requested, isEmpty);
    });
  });
}

Future<void> _pumpDetail(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seerrApiProvider.overrideWith((Ref ref, Instance i) async => api),
      ],
      child: const MaterialApp(
        home: SeerrItemDetailScreen(
          instance: _instance,
          item: SeerrDiscoverResult(id: 5, title: 'Film'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A Seerr with two pending requests, one by the user (id 7) and one by
/// someone else, answering `auth/me` with [me].
class _FakeApi extends SeerrApi {
  _FakeApi(this.user, {this.meFuture})
      : super(Dio(BaseOptions(baseUrl: 'http://seerr.test/')));

  final SeerrUser user;
  final Future<SeerrUser>? meFuture;

  /// The is4k of every request made.
  final List<bool> requested = <bool>[];

  @override
  Future<SeerrUser> me() => meFuture ?? Future<SeerrUser>.value(user);

  @override
  Future<List<SeerrServer>> getServers(String mediaType) async =>
      throw Exception('servers unavailable');

  @override
  Future<SeerrRequest> createRequest({
    required String mediaType,
    required int mediaId,
    bool is4k = false,
    int? serverId,
    int? profileId,
    String? rootFolder,
  }) async {
    requested.add(is4k);
    return SeerrRequest(id: 1, type: mediaType);
  }

  @override
  Future<List<SeerrDiscoverResult>> getRecommendations(
    String mediaType,
    int tmdbId,
  ) async =>
      <SeerrDiscoverResult>[];

  @override
  Future<List<SeerrDiscoverResult>> getSimilar(
    String mediaType,
    int tmdbId,
  ) async =>
      <SeerrDiscoverResult>[];

  @override
  Future<List<SeerrRequest>> getAllRequests({
    String sort = 'added',
    String? filter,
    bool ownOnly = false,
  }) async =>
      <SeerrRequest>[_request(by: 7), _request(by: 3)];

  @override
  Future<SeerrDiscoverResult> getMediaDetails(
    String mediaType,
    int tmdbId,
  ) async =>
      SeerrDiscoverResult(id: tmdbId, title: 'Title $tmdbId');
}

const Instance _instance = Instance(
  id: 'test-seerr',
  name: 'Test Seerr',
  kind: ServiceKind.seerr,
  localUrl: 'http://seerr.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.cookieLogin(username: 'kid@example.com', password: 'p'),
);

Future<void> _pumpHome(WidgetTester tester, SeerrUser me) async {
  final _FakeApi api = _FakeApi(me);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seerrApiProvider.overrideWith((Ref ref, Instance i) async => api),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SeerrHome(instance: _instance)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Unmounts the screen so the polled request list leaves no timer behind.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 11));
}
