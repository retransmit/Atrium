import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_client_edit.dart';
import '../adguard_home_clients_view.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_clients.dart';

/// Whom a name is checked for: a client by the address the server takes,
/// or, with no [address], no client in particular.
class AdguardHomeCheckClient {
  const AdguardHomeCheckClient({required this.label, this.address});

  /// The server's own settings, as for a device it knows nothing of.
  static const AdguardHomeCheckClient any =
      AdguardHomeCheckClient(label: 'Any client');

  /// What the client is called here: its name, or its address.
  final String label;
  final String? address;

  /// The label, with the address beside a name.
  String get description => address == null || address == label
      ? label
      : '$label ($address)';
}

/// Lets the user pick whom a name is checked for, from [instance]'s clients
/// or by typing an address. Null when the sheet was closed.
Future<AdguardHomeCheckClient?> pickAdguardHomeCheckClient(
  BuildContext context, {
  required Instance instance,
  required AdguardHomeCheckClient current,
}) =>
    showModalBottomSheet<AdguardHomeCheckClient>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: (BuildContext _) =>
          AdguardHomeCheckClientPicker(instance: instance, current: current),
    );

/// The clients a name can be checked for. The server checks for a client
/// by its address alone, so one known only by a MAC address or a ClientID
/// is listed but cannot be picked.
class AdguardHomeCheckClientPicker extends ConsumerStatefulWidget {
  const AdguardHomeCheckClientPicker({
    required this.instance,
    required this.current,
    super.key,
  });

  final Instance instance;
  final AdguardHomeCheckClient current;

  @override
  ConsumerState<AdguardHomeCheckClientPicker> createState() =>
      _AdguardHomeCheckClientPickerState();
}

class _AdguardHomeCheckClientPickerState
    extends ConsumerState<AdguardHomeCheckClientPicker> {
  final TextEditingController _address = TextEditingController();
  bool _checked = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  String? get _problem {
    final String text = _address.text.trim();
    if (text.isEmpty) return 'Enter an IP address.';
    if (adguardHomeAddressBytes(text) == null) {
      return 'An IP address, such as 192.168.1.20.';
    }
    return null;
  }

  void _pick(AdguardHomeCheckClient client) =>
      Navigator.of(context).pop(client);

  void _typed() {
    if (_problem != null) {
      setState(() => _checked = true);
      return;
    }
    final String address = _address.text.trim();
    _pick(AdguardHomeCheckClient(label: address, address: address));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<AdguardHomeClientsView> clients =
        ref.watch(adguardHomeClientsProvider(widget.instance));
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: Insets.lg),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.sm),
          child: Text(
            'Check for',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _option(AdguardHomeCheckClient.any, subtitle: "The server's settings"),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.lg,
            Insets.sm,
          ),
          child: TextField(
            key: const Key('adguard-check-address'),
            controller: _address,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_checked) setState(() {});
            },
            onSubmitted: (_) => _typed(),
            decoration: InputDecoration(
              labelText: 'An IP address',
              border: const OutlineInputBorder(),
              errorText: _checked ? _problem : null,
              suffixIcon: IconButton(
                tooltip: 'Check for this address',
                icon: const Icon(Icons.arrow_forward),
                onPressed: _typed,
              ),
            ),
          ),
        ),
        ...clients.when(
          skipLoadingOnReload: true,
          loading: () => const <Widget>[
            Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: Center(child: ExpressiveProgressIndicator()),
            ),
          ],
          error: (Object error, StackTrace _) => <Widget>[
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text(
                describeAdguardHomeError(error),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
          data: (AdguardHomeClientsView view) => _clients(theme, view),
        ),
      ],
    );
  }

  List<Widget> _clients(ThemeData theme, AdguardHomeClientsView view) {
    final List<AdguardHomeRuntimeRow> runtime = <AdguardHomeRuntimeRow>[
      for (final AdguardHomeRuntimeRow row in view.runtime)
        if (adguardHomeAddressBytes(row.client.address) != null) row,
    ];
    return <Widget>[
      if (view.persistent.isNotEmpty) _heading(theme, 'Persistent clients'),
      for (final AdguardHomePersistentRow row in view.persistent)
        _persistent(row.client),
      if (runtime.isNotEmpty) _heading(theme, 'Runtime clients'),
      for (final AdguardHomeRuntimeRow row in runtime)
        _option(
          AdguardHomeCheckClient(
            label: row.client.name.isEmpty
                ? row.client.address
                : row.client.name,
            address: row.client.address,
          ),
          subtitle: row.client.name.isEmpty ? null : row.client.address,
        ),
    ];
  }

  Widget _persistent(AdguardHomeClient client) {
    final String? address = adguardHomeCheckAddressOf(client);
    if (address == null) {
      return ListTile(
        enabled: false,
        title: Text(client.name),
        subtitle: const Text(
          'Known by no IP address, which is all the server checks by',
        ),
      );
    }
    return _option(
      AdguardHomeCheckClient(label: client.name, address: address),
      subtitle: address,
    );
  }

  Widget _option(AdguardHomeCheckClient client, {String? subtitle}) {
    final bool chosen = client.address == widget.current.address;
    return ListTile(
      title: Text(client.label),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: chosen ? const Icon(Icons.check) : null,
      selected: chosen,
      onTap: () => _pick(client),
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.xs,
        ),
        child: Text(
          text,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      );
}
