import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filters.dart';
import '../models/adguard_home_services.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_refused_view.dart';
import '../widgets/adguard_home_schedule_editor.dart';
import 'adguard_home_services_screen.dart';

/// The services the server blocks for every client that uses the global
/// list, and when that blocking pauses.
class AdguardHomeGlobalServicesScreen extends ConsumerStatefulWidget {
  const AdguardHomeGlobalServicesScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeGlobalServicesScreen> createState() =>
      _AdguardHomeGlobalServicesScreenState();
}

class _AdguardHomeGlobalServicesScreenState
    extends ConsumerState<AdguardHomeGlobalServicesScreen> {
  bool _busy = false;

  Instance get _instance => widget.instance;

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  Future<void> _write(Future<void> Function() write, String done) async {
    if (_busy) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String message = done;
    try {
      await write();
    } on Object catch (error) {
      message = describeAdguardHomeError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick(List<String> blocked) async {
    final Set<String>? picked = await pushScreen<Set<String>>(
      context,
      AdguardHomeServicesScreen(
        instance: _instance,
        title: 'Blocked for everyone',
        selected: blocked.toSet(),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.length == blocked.length && picked.containsAll(blocked)) return;
    final AdguardHomeServiceCatalogue? catalogue =
        ref.read(adguardHomeServicesProvider(_instance)).value;
    final List<String> kept = <String>[
      for (final String id in blocked)
        if (picked.contains(id)) id,
    ];
    final List<String> ids = <String>[
      ...kept,
      // New ones in the catalogue's order, where it is known.
      if (catalogue != null)
        for (final AdguardHomeBlockedService service in catalogue.services)
          if (picked.contains(service.id) && !kept.contains(service.id))
            service.id,
    ];
    for (final String id in picked) {
      if (!ids.contains(id)) ids.add(id);
    }
    await _write(
      () => _actions.setGlobalServiceIds(ids),
      'Blocked services saved',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeGlobalServices> services =
        ref.watch(adguardHomeGlobalServicesProvider(_instance));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked services'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _busy
              ? const LinearProgressIndicatorM3E(
                  size: LinearProgressM3ESize.s,
                  shape: ProgressM3EShape.flat,
                )
              : const SizedBox(height: 4),
        ),
      ),
      body: _body(services),
    );
  }

  Widget _body(AsyncValue<AdguardHomeGlobalServices> services) {
    if (services.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _actions.retrySignIn,
        onEdit: () => context.pushNamed(
          AtriumRoutes.editInstanceName,
          pathParameters: <String, String>{'instanceId': _instance.id},
        ),
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }
    return services.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (Object error, StackTrace _) => SingleChildScrollView(
        child: ErrorView(
          message: describeAdguardHomeError(error),
          onRetry: () =>
              ref.invalidate(adguardHomeGlobalServicesProvider(_instance)),
        ),
      ),
      data: (AdguardHomeGlobalServices services) {
        final ThemeData theme = Theme.of(context);
        // Read only to name what is blocked.
        final AdguardHomeServiceCatalogue? catalogue = services.ids.isEmpty
            ? null
            : ref.watch(adguardHomeServicesProvider(_instance)).value;
        return AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.lg),
                child: AdguardHomeHeading('Blocked for everyone'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.xs,
                  Insets.lg,
                  0,
                ),
                child: Text(
                  'Clients with their own list of blocked services are not '
                  'covered by this one.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              ListTile(
                title: const Text('Services'),
                subtitle: Text(
                  services.ids.isEmpty
                      ? 'None'
                      : <String>[
                          for (final String id in services.ids)
                            catalogue?.nameOf(id) ?? id,
                        ].join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pick(services.ids),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.lg),
                child: AdguardHomeHeading('Pause schedule'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.xs,
                  Insets.lg,
                  0,
                ),
                child: Text(
                  services.ids.isEmpty
                      ? 'Nothing is blocked now, so there is nothing to pause. '
                          'The schedule is kept for when something is.'
                      : 'While paused, the services above are let through.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              AdguardHomeScheduleEditor(
                schedule: services.schedule,
                enabled: !_busy,
                onChanged: (AdguardHomeSchedule next) => _write(
                  () => _actions.setGlobalSchedule(next),
                  'Schedule saved',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
