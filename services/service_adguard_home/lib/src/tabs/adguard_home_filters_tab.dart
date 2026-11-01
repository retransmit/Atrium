import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_filter_rules.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../models/adguard_home_filters.dart';
import '../screens/adguard_home_custom_rules_screen.dart';
import '../screens/adguard_home_filter_lists_screen.dart';
import '../screens/adguard_home_global_services_screen.dart';
import '../screens/adguard_home_rewrites_screen.dart';
import '../widgets/adguard_home_host_check.dart';
import '../widgets/adguard_home_pullable.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The filters, as five sections each summed up in a line and opened on its
/// own screen, under a field to check what the server does with a name.
class AdguardHomeFiltersTab extends ConsumerStatefulWidget {
  const AdguardHomeFiltersTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeFiltersTab> createState() =>
      _AdguardHomeFiltersTabState();
}

class _AdguardHomeFiltersTabState extends ConsumerState<AdguardHomeFiltersTab> {
  final TextEditingController _host = TextEditingController();

  Instance get _instance => widget.instance;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  void _check(String text) {
    final String name = text.trim();
    if (name.isEmpty) return;
    showAdguardHomeHostCheck(context, instance: _instance, name: name);
  }

  void _open(Widget screen) => pushScreen<void>(context, screen);

  Future<void> _refresh() async {
    ref
      ..invalidate(adguardHomeFilteringProvider(_instance))
      ..invalidate(adguardHomeGlobalServicesProvider(_instance))
      ..invalidate(adguardHomeRewritesProvider(_instance))
      ..invalidate(adguardHomeRewritesEnabledProvider(_instance));
    try {
      await ref.read(adguardHomeFilteringProvider(_instance).future);
    } on Object {
      // The tab shows the failure itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeFiltering> filtering =
        ref.watch(adguardHomeFilteringProvider(_instance));
    if (filtering.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: ref.read(adguardHomeActionsProvider(_instance)).retrySignIn,
        onEdit: () => context.pushNamed(
          AtriumRoutes.editInstanceName,
          pathParameters: <String, String>{'instanceId': _instance.id},
        ),
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }
    final AsyncValue<AdguardHomeGlobalServices> services =
        ref.watch(adguardHomeGlobalServicesProvider(_instance));
    final AsyncValue<List<AdguardHomeRewrite>> rewrites =
        ref.watch(adguardHomeRewritesProvider(_instance));
    final bool? rewritesOn =
        ref.watch(adguardHomeRewritesEnabledProvider(_instance)).value;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AdguardHomePullable(
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.sm,
            ),
            child: TextField(
              controller: _host,
              onSubmitted: _check,
              onTapOutside: (PointerDownEvent _) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'Check a host, such as example.org',
                prefixIcon: const Icon(Icons.travel_explore),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _Section(
            icon: Icons.block,
            title: 'Blocklists',
            summary: _summary(
              filtering,
              (AdguardHomeFiltering f) => _lists(f.blocklists),
            ),
            onTap: () => _open(
              AdguardHomeFilterListsScreen(
                instance: _instance,
                allowlist: false,
              ),
            ),
          ),
          _Section(
            icon: Icons.verified_outlined,
            title: 'Allowlists',
            summary: _summary(
              filtering,
              (AdguardHomeFiltering f) => _lists(f.allowlists),
            ),
            onTap: () => _open(
              AdguardHomeFilterListsScreen(
                instance: _instance,
                allowlist: true,
              ),
            ),
          ),
          _Section(
            icon: Icons.edit_note,
            title: 'Custom rules',
            summary: _summary(
              filtering,
              (AdguardHomeFiltering f) => _count(
                adguardHomeRuleCount(adguardHomeRulesToText(f.userRules)),
                'rule',
              ),
            ),
            onTap: () =>
                _open(AdguardHomeCustomRulesScreen(instance: _instance)),
          ),
          _Section(
            icon: Icons.apps,
            title: 'Blocked services',
            summary: _summary(services, (AdguardHomeGlobalServices s) {
              final String blocked =
                  s.ids.isEmpty ? 'None' : _count(s.ids.length, 'service');
              final int days = s.schedule.pauses.length;
              return days == 0
                  ? blocked
                  : '$blocked · pauses on ${_count(days, 'day')}';
            }),
            onTap: () =>
                _open(AdguardHomeGlobalServicesScreen(instance: _instance)),
          ),
          _Section(
            icon: Icons.alt_route,
            title: 'DNS rewrites',
            summary: _summary(rewrites, (List<AdguardHomeRewrite> r) {
              if (rewritesOn == false) {
                return 'Off · ${_count(r.length, 'rewrite')}';
              }
              if (r.isEmpty) return 'None';
              // A server without switches has every rewrite on.
              if (!r.any((AdguardHomeRewrite x) => x.switchable)) {
                return _count(r.length, 'rewrite');
              }
              final int on =
                  r.where((AdguardHomeRewrite x) => x.enabled).length;
              return '${_count(r.length, 'rewrite')}, $on on';
            }),
            onTap: () => _open(AdguardHomeRewritesScreen(instance: _instance)),
          ),
        ],
      ),
    );
  }

  static String _lists(List<AdguardHomeFilterList> lists) {
    if (lists.isEmpty) return 'None';
    final List<AdguardHomeFilterList> on = <AdguardHomeFilterList>[
      for (final AdguardHomeFilterList list in lists)
        if (list.enabled) list,
    ];
    final int rules = on.fold<int>(
      0,
      (int sum, AdguardHomeFilterList list) => sum + list.rulesCount,
    );
    return '${_count(lists.length, 'list')}, ${on.length} on · '
        '${formatAdguardHomeCount(rules)} rules';
  }

  static String _count(int count, String thing) =>
      count == 1 ? '1 $thing' : '$count ${thing}s';

  /// A section's line: what [describe] makes of the read, or a word for a
  /// read that is under way or failed.
  static String _summary<T>(AsyncValue<T> value, String Function(T) describe) {
    final T? read = value.value;
    if (read != null) return describe(read);
    if (value.hasError) return 'Could not be read';
    return 'Reading...';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(summary),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
