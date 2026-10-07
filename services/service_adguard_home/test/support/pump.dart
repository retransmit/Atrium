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

  @override
  Future<AdguardHomeRuleEdit> toggleBlocking(
    String domain, {
    required bool block,
  }) async {
    calls.add('${block ? 'block' : 'unblock'} $domain');
    final String rule =
        block ? '||$domain^\$important' : '@@||$domain^\$important';
    return AdguardHomeRuleEdit(<String>[rule], change, rule);
  }
}

/// What a pumped screen was built on, for the test to look at.
class Pumped {
  late RecordingActions actions;

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
  Object? statusError,
  Object? statsError,
  Size size = const Size(360, 2400),
  double textScale = 1,
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
  const Instance instance = adguardHomeTestInstance;
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
