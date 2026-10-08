import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'adguard_home_clients_fixtures.dart';
import 'adguard_home_test_instance.dart';

/// Stands in for [AdguardHomeActions], noting what the screen asked for
/// instead of sending anything.
class RecordingActions extends AdguardHomeActions {
  RecordingActions(super.ref, super.instance);

  final List<String> calls = <String>[];

  /// What [toggleBlocking] reports back.
  AdguardHomeRuleChange change = AdguardHomeRuleChange.added;

  /// When set, [setProtection] fails with it.
  Object? failure;

  @override
  Future<void> setProtection({required bool enabled, Duration? pause}) async {
    calls.add('protection enabled=$enabled pause=${pause?.inSeconds}');
    final Object? error = failure;
    if (error != null) throw error;
  }

  @override
  void retrySignIn() => calls.add('retry');

  @override
  void refresh() => calls.add('refresh');

  /// What [readAccessList] hands back.
  AdguardHomeAccessList accessList = const AdguardHomeAccessList();

  /// When set, [setClientAccess] and [clearQueryLog] fail with it.
  Object? writeFailure;

  /// While set, [setClientAccess] waits on this before it answers, so a
  /// test can do things while the write is on its way.
  Completer<void>? writeHold;

  @override
  Future<AdguardHomeRuleEdit> toggleBlocking(
    String domain, {
    required bool block,
    String? clientAddress,
  }) async {
    calls.add(
      '${block ? 'block' : 'unblock'} $domain'
      '${clientAddress == null ? '' : ' for $clientAddress'}',
    );
    final String base = clientAddress == null
        ? '||$domain^\$important'
        : "||$domain^\$client='$clientAddress'";
    final String rule = block ? base : '@@$base';
    return AdguardHomeRuleEdit(<String>[rule], change, rule);
  }

  @override
  Future<AdguardHomeAccessList> readAccessList() async {
    calls.add('read access');
    return accessList;
  }

  @override
  Future<void> setClientAccess({
    required String address,
    required bool disallowed,
    required String disallowedRule,
  }) async {
    calls.add(
      '${disallowed ? 'allow' : 'disallow'} $address rule=$disallowedRule',
    );
    final Completer<void>? held = writeHold;
    if (held != null) await held.future;
    final Object? error = writeFailure;
    if (error != null) throw error;
  }

  @override
  Future<void> clearQueryLog() async {
    calls.add('clear log');
    final Object? error = writeFailure;
    if (error != null) throw error;
  }

  /// Every client the form asked to save: the name it had, null for a new
  /// one, with what the form started from and what it held.
  final List<SavedClient> saved = <SavedClient>[];

  /// What [findClient] hands back. Without one it knows nothing of the
  /// address.
  AdguardHomeClientLookup? lookup;

  /// When set, [findClient] fails with it.
  Object? lookupFailure;

  /// While set, [findClient] waits on this before it answers.
  Completer<void>? lookupHold;

  /// Waits and fails as [writeHold] and [writeFailure] say.
  Future<void> _write() async {
    final Completer<void>? held = writeHold;
    if (held != null) await held.future;
    final Object? error = writeFailure;
    if (error != null) throw error;
  }

  @override
  Future<void> saveClient({
    required AdguardHomeClientDraft before,
    required AdguardHomeClientDraft after,
    String? originalName,
  }) async {
    calls.add('save ${originalName ?? '(new)'} as ${after.name.trim()}');
    saved.add((originalName: originalName, before: before, after: after));
    await _write();
  }

  @override
  Future<void> deleteClient(String name) async {
    calls.add('delete client $name');
    await _write();
  }

  @override
  Future<AdguardHomeClientLookup> findClient(
    String address, {
    int? queries,
  }) async {
    calls.add('find $address');
    final Completer<void>? held = lookupHold;
    if (held != null) await held.future;
    final Object? error = lookupFailure;
    if (error != null) throw error;
    return lookup ?? AdguardHomeClientLookup(address: address, queries: queries);
  }
}

/// One call to save a client, as [RecordingActions] noted it.
typedef SavedClient = ({
  String? originalName,
  AdguardHomeClientDraft before,
  AdguardHomeClientDraft after,
});

/// The clients of the captured fixtures, as the Clients tab lists them: the
/// top clients are the two the test server had, plus the ClientID.
AdguardHomeClientsView capturedClients() => AdguardHomeClientsView.build(
      list: AdguardHomeClientList.fromJson(clientListJson()),
      topClients: const <AdguardHomeCount>[
        AdguardHomeCount('172.17.0.1', 150),
        AdguardHomeCount('127.0.0.1', 122),
        AdguardHomeCount('work-phone', 7),
      ],
      found: AdguardHomeFoundClient.mapFromJson(clientSearchJson()),
    );

/// One of the captured persistent clients.
AdguardHomeClient capturedClient(String name) =>
    AdguardHomeClientList.fromJson(clientListJson())
        .persistent
        .firstWhere((AdguardHomeClient client) => client.name == name);

/// Stands in for [AdguardHomeQueryLog]: shows the state a test gives it and
/// notes what the screen asked of it, without reading anything.
class RecordingQueryLog extends AdguardHomeQueryLog {
  RecordingQueryLog(super.instance, this._initial);

  final AdguardHomeQueryLogState _initial;

  final List<String> calls = <String>[];

  @override
  AdguardHomeQueryLogState build() => _initial;

  /// Puts [next] on the screen.
  void show(AdguardHomeQueryLogState next) => state = next;

  @override
  Future<void> reload() async => calls.add('reload');

  @override
  Future<void> loadMore() async {
    calls.add('more');
    // As the real one does, so the list stops asking.
    state = state.copyWith(loadingMore: true, stalled: false, clearError: true);
  }

  @override
  Future<void> setSearch(String text) async {
    calls.add('search $text');
    state = AdguardHomeQueryLogState(
      entries: state.entries,
      search: text.trim(),
      filter: state.filter,
      reachedEnd: state.reachedEnd,
    );
  }

  @override
  Future<void> clearNarrowing() async {
    calls.add('clear');
    state = AdguardHomeQueryLogState(
      entries: state.entries,
      reachedEnd: state.reachedEnd,
    );
  }

  @override
  Future<void> setFilter(AdguardHomeLogFilter filter) async {
    calls.add('filter ${filter.name}');
    state = AdguardHomeQueryLogState(
      entries: state.entries,
      search: state.search,
      filter: filter,
      reachedEnd: state.reachedEnd,
    );
  }
}

/// A session that says it has been refused [refusals] times in a row,
/// without anything having been sent.
class RefusedSession extends AdguardHomeSession {
  RefusedSession(this._count);

  final int _count;

  @override
  int get refusals => _count;
}

/// What a pumped screen was built on, for the test to look at.
class Pumped {
  late RecordingActions actions;

  /// The query log the screen is showing. Only there once the screen has
  /// asked for it, which [logWatched] tells.
  late RecordingQueryLog log;

  /// Whether anything has asked for the query log yet.
  bool logWatched = false;

  /// How many times the status was read.
  int statusReads = 0;

  /// How many times the clients were read.
  int clientReads = 0;

  /// How many times the server's own safe search was read.
  int safeSearchReads = 0;

  /// How many times the catalogue of services was read.
  int servicesReads = 0;
}

/// Pumps [child] with the four reads answered from fixed values and the
/// actions recorded. Nothing here polls, so no timer outlives the test.
///
/// The screen is tall by default so the whole tab is laid out: a list only
/// builds what is near the viewport, and a row that was never built can
/// neither be found nor overflow.
Future<Pumped> pumpAdguardHome(
  WidgetTester tester,
  Widget child, {
  AdguardHomeStatus? status,
  AdguardHomeStats stats = const AdguardHomeStats(),
  AdguardHomeFiltering filtering = const AdguardHomeFiltering(),
  Duration period = const Duration(hours: 24),
  AdguardHomeQueryLogState log = const AdguardHomeQueryLogState(),
  AdguardHomeQueryLogConfig logConfig = const AdguardHomeQueryLogConfig(),
  Object? statusError,
  Object? statsError,
  AdguardHomeClientsView? clients,
  Object? clientsError,
  AdguardHomeSafeSearch? safeSearch,
  Object? safeSearchError,
  AdguardHomeServiceCatalogue? services,
  Size size = const Size(360, 2400),
  double textScale = 1,
  Instance instance = adguardHomeTestInstance,
  AdguardHomeSession? session,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final Pumped pumped = Pumped();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        if (session != null)
          adguardHomeSessionProvider(instance).overrideWithValue(session),
        adguardHomeStatusProvider(instance).overrideWith((Ref ref) async {
          pumped.statusReads++;
          if (statusError != null) throw statusError;
          return status!;
        }),
        adguardHomeStatsProvider(instance).overrideWith((Ref ref) async {
          if (statsError != null) throw statsError;
          return stats;
        }),
        adguardHomeFilteringProvider(instance)
            .overrideWith((Ref ref) async => filtering),
        adguardHomeStatsPeriodProvider(instance)
            .overrideWith((Ref ref) async => period),
        adguardHomeQueryLogProvider(instance).overrideWith(() {
          pumped.logWatched = true;
          return pumped.log = RecordingQueryLog(instance, log);
        }),
        adguardHomeQueryLogConfigProvider(instance)
            .overrideWith((Ref ref) async => logConfig),
        adguardHomeClientsProvider(instance).overrideWith((Ref ref) async {
          pumped.clientReads++;
          if (clientsError != null) throw clientsError;
          return clients ?? capturedClients();
        }),
        adguardHomeSafeSearchProvider(instance).overrideWith((Ref ref) async {
          pumped.safeSearchReads++;
          // Only the first read fails, so a test can try again.
          if (safeSearchError != null && pumped.safeSearchReads == 1) {
            throw safeSearchError;
          }
          return safeSearch ?? AdguardHomeSafeSearch.fromJson(safeSearchJson());
        }),
        adguardHomeServicesProvider(instance).overrideWith((Ref ref) async {
          pumped.servicesReads++;
          return services ??
              AdguardHomeServiceCatalogue.fromJson(blockedServicesJson());
        }),
        adguardHomeActionsProvider(instance).overrideWith(
          (Ref ref) => pumped.actions = RecordingActions(ref, instance),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  // One pump per async stage: the futures resolve, then the frame.
  await tester.pump();
  await tester.pump();
  // A screen only asks for the actions when something is tapped. Ask now, so
  // a test can set them up before the tap.
  ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
    listen: false,
  ).read(adguardHomeActionsProvider(instance));
  return pumped;
}
