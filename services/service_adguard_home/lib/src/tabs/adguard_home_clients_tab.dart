import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adguard_home_clients_view.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_clients.dart';
import '../screens/adguard_home_client_screen.dart';
import '../widgets/adguard_home_client_rows.dart';
import '../widgets/adguard_home_client_sheet.dart';
import '../widgets/adguard_home_pullable.dart';
import '../widgets/adguard_home_refused_view.dart';

/// Which of the two lists is showing.
enum _Kind { persistent, runtime }

/// The server's clients: those it has settings for, and those it has merely
/// seen. A persistent client opens its form; a runtime one opens what the
/// server knows of it, with a way to make it persistent.
///
/// Nothing here is read on a timer. Pulling down reads the lists again.
class AdguardHomeClientsTab extends ConsumerStatefulWidget {
  const AdguardHomeClientsTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeClientsTab> createState() =>
      _AdguardHomeClientsTabState();
}

class _AdguardHomeClientsTabState extends ConsumerState<AdguardHomeClientsTab> {
  /// Room under the last row for the button that floats over the list.
  static const double _underButton = 96;

  _Kind _kind = _Kind.persistent;

  Instance get _instance => widget.instance;

  /// Reads the lists again and holds the pull-to-refresh indicator until
  /// they are back.
  Future<void> _refresh() async {
    ref.invalidate(adguardHomeClientsProvider(_instance));
    try {
      await ref.read(adguardHomeClientsProvider(_instance).future);
    } on Object {
      // The tab shows the failure itself; the indicator only has to stop.
    }
  }

  void _edit() {
    context.pushNamed(
      AtriumRoutes.editInstanceName,
      pathParameters: <String, String>{'instanceId': _instance.id},
    );
  }

  void _openRuntime(AdguardHomeClientsView view, AdguardHomeRuntimeRow row) {
    AdguardHomeClient? owner;
    for (final AdguardHomePersistentRow persistent in view.persistent) {
      if (persistent.client.name == row.owner) owner = persistent.client;
    }
    showAdguardHomeClientSheet(
      context,
      instance: _instance,
      address: row.client.address,
      queries: row.queries,
      // When the list knows whose the address is, everything the sheet
      // shows is in the list already. When it does not, the sheet asks: the
      // list has the server's word only for the top clients, and matched
      // here a device that a client names by its MAC address looks like
      // nobody's. Offered as a new client, it would become a second one,
      // and the server goes by an address before it goes by a MAC address.
      lookup: owner == null
          ? null
          : AdguardHomeClientLookup(
              address: row.client.address,
              persistent: owner,
              runtime: row.client,
              supportedTags: view.supportedTags,
              queries: row.queries,
              serverSaid: true,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeClientsView> clients =
        ref.watch(adguardHomeClientsProvider(_instance));

    if (clients.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: ref.read(adguardHomeActionsProvider(_instance)).retrySignIn,
        onEdit: _edit,
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }

    return clients.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (Object error, StackTrace _) => AdguardHomePullable(
        onRefresh: _refresh,
        child: ErrorView(
          message: describeAdguardHomeError(error),
          onRetry: () => ref.invalidate(adguardHomeClientsProvider(_instance)),
        ),
      ),
      data: (AdguardHomeClientsView view) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Kind>(
                showSelectedIcon: false,
                segments: <ButtonSegment<_Kind>>[
                  ButtonSegment<_Kind>(
                    value: _Kind.persistent,
                    label: _SegmentLabel(
                      'Persistent (${view.persistent.length})',
                    ),
                  ),
                  ButtonSegment<_Kind>(
                    value: _Kind.runtime,
                    label: _SegmentLabel('Runtime (${view.runtime.length})'),
                  ),
                ],
                selected: <_Kind>{_kind},
                onSelectionChanged: (Set<_Kind> chosen) =>
                    setState(() => _kind = chosen.single),
              ),
            ),
          ),
          Expanded(
            child: switch (_kind) {
              _Kind.persistent => _persistent(view),
              _Kind.runtime => _runtime(view),
            },
          ),
        ],
      ),
    );
  }

  Widget _persistent(AdguardHomeClientsView view) {
    if (view.persistent.isEmpty) {
      return AdguardHomePullable(
        onRefresh: _refresh,
        child: const EmptyView(
          icon: Icons.devices_other,
          title: 'No persistent clients',
          message: 'A persistent client is a device with a name and, if it '
              'needs them, settings of its own. Add one below, or from the '
              'runtime clients.',
        ),
      );
    }
    return EasyRefresh(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: _underButton),
        itemCount: view.persistent.length,
        separatorBuilder: _divider,
        itemBuilder: (BuildContext context, int index) {
          final AdguardHomePersistentRow row = view.persistent[index];
          return AdguardHomePersistentClientRow(
            row: row,
            onTap: () => adguardHomeEditClient(
              context,
              instance: _instance,
              supportedTags: view.supportedTags,
              client: row.client,
            ),
          );
        },
      ),
    );
  }

  Widget _runtime(AdguardHomeClientsView view) {
    if (view.runtime.isEmpty) {
      return AdguardHomePullable(
        onRefresh: _refresh,
        child: const EmptyView(
          icon: Icons.sensors_off,
          title: 'No runtime clients',
          message: 'AdGuard Home has not seen a device yet.',
        ),
      );
    }
    return EasyRefresh(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: _underButton),
        itemCount: view.runtime.length,
        separatorBuilder: _divider,
        itemBuilder: (BuildContext context, int index) {
          final AdguardHomeRuntimeRow row = view.runtime[index];
          return AdguardHomeRuntimeClientRow(
            row: row,
            onTap: () => _openRuntime(view, row),
          );
        },
      ),
    );
  }

  static Widget _divider(BuildContext _, int __) => const Divider(
        height: 1,
        indent: Insets.lg,
        endIndent: Insets.lg,
      );
}

/// A segment's label. It shrinks rather than run out of its half of the
/// screen at a large text size.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text));
}
