import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

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
    final Object? error = writeFailure;
    if (error != null) throw error;
  }

  @override
  Future<void> clearQueryLog() async {
    calls.add('clear log');
    final Object? error = writeFailure;
    if (error != null) throw error;
  }
}

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

/// What a pumped screen was built on, for the test to look at.
class Pumped {
  late RecordingActions actions;

  /// The query log the screen is showing. Only there once the screen has
  /// asked for it.
  late RecordingQueryLog log;

  /// How many times the status was read.
  int statusReads = 0;
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
  Size size = const Size(360, 2400),
  double textScale = 1,
  Instance instance = adguardHomeTestInstance,
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
        adguardHomeQueryLogProvider(instance).overrideWith(
          () => pumped.log = RecordingQueryLog(instance, log),
        ),
        adguardHomeQueryLogConfigProvider(instance)
            .overrideWith((Ref ref) async => logConfig),
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
