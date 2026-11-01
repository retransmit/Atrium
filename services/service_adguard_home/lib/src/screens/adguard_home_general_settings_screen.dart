import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_clients.dart';
import '../models/adguard_home_filtering.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The server's protection: filtering by the lists, safe browsing, parental
/// control and safe search. Each switch is written as soon as it is moved,
/// as on the web UI.
class AdguardHomeGeneralSettingsScreen extends ConsumerStatefulWidget {
  const AdguardHomeGeneralSettingsScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeGeneralSettingsScreen> createState() =>
      _AdguardHomeGeneralSettingsScreenState();
}

class _AdguardHomeGeneralSettingsScreenState
    extends ConsumerState<AdguardHomeGeneralSettingsScreen> {
  /// The switch being written, by name, with the place it was moved to.
  /// Shown until the server has been read again, and nothing else can be
  /// moved meanwhile.
  String? _busy;
  bool _moved = false;

  Instance get _instance => widget.instance;

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  bool _shown(String key, bool read) => _busy == key ? _moved : read;

  Future<void> _write(
    String key,
    bool on,
    Future<void> Function() write,
  ) async {
    if (_busy != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = key;
      _moved = on;
    });
    try {
      await write();
      // The write reads the setting again. Waited for, so the switch does
      // not go back to where it was for a moment.
      await Future.wait(<Future<Object?>>[
        ref.read(adguardHomeFilteringProvider(_instance).future),
        ref.read(adguardHomeGeneralSettingsProvider(_instance).future),
      ]);
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(describeAdguardHomeError(error))),
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(adguardHomeFilteringProvider(_instance))
      ..invalidate(adguardHomeGeneralSettingsProvider(_instance));
    try {
      await ref.read(adguardHomeGeneralSettingsProvider(_instance).future);
    } on Object {
      // The screen shows the failure itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeFiltering> filtering =
        ref.watch(adguardHomeFilteringProvider(_instance));
    final AsyncValue<AdguardHomeGeneralSettings> general =
        ref.watch(adguardHomeGeneralSettingsProvider(_instance));
    return Scaffold(
      appBar: AppBar(
        title: const Text('General'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _busy != null
              ? const LinearProgressIndicatorM3E(
                  size: LinearProgressM3ESize.s,
                  shape: ProgressM3EShape.flat,
                )
              : const SizedBox(height: 4),
        ),
      ),
      body: _body(filtering, general),
    );
  }

  Widget _body(
    AsyncValue<AdguardHomeFiltering> filtering,
    AsyncValue<AdguardHomeGeneralSettings> general,
  ) {
    final Object? error = general.error ?? filtering.error;
    if (error is AdguardHomeSignInRefused) {
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
    final AdguardHomeFiltering? lists = filtering.value;
    final AdguardHomeGeneralSettings? read = general.value;
    if (lists == null || read == null) {
      if (error != null) {
        return SingleChildScrollView(
          child: ErrorView(
            message: describeAdguardHomeError(error),
            onRetry: _refresh,
          ),
        );
      }
      return const Center(child: ExpressiveProgressIndicator());
    }

    final bool idle = _busy == null;
    final AdguardHomeSafeSearch safeSearch = read.safeSearch;
    final bool safeSearchOn = _shown('safesearch', safeSearch.enabled);
    return EasyRefresh(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          SwitchListTile(
            title: const Text('Block domains using filters and hosts files'),
            subtitle: const Text('The blocklists, allowlists and custom rules'),
            value: _shown('filtering', lists.enabled),
            onChanged: idle
                ? (bool on) => _write(
                      'filtering',
                      on,
                      () => _actions.setFilteringEnabled(enabled: on),
                    )
                : null,
          ),
          SwitchListTile(
            title: const Text('Browsing security'),
            subtitle: const Text('Blocks malware and phishing domains'),
            value: _shown('safebrowsing', read.safeBrowsing),
            onChanged: idle
                ? (bool on) => _write(
                      'safebrowsing',
                      on,
                      () => _actions.setSafeBrowsing(enabled: on),
                    )
                : null,
          ),
          SwitchListTile(
            title: const Text('Parental control'),
            subtitle: const Text('Blocks adult websites'),
            value: _shown('parental', read.parental),
            onChanged: idle
                ? (bool on) => _write(
                      'parental',
                      on,
                      () => _actions.setParental(enabled: on),
                    )
                : null,
          ),
          SwitchListTile(
            title: const Text('Safe search'),
            subtitle: const Text(
              'Hides explicit results on the search engines below',
            ),
            value: safeSearchOn,
            onChanged: idle
                ? (bool on) => _write(
                      'safesearch',
                      on,
                      () => _actions.setSafeSearch(
                        before: safeSearch,
                        after: safeSearch.copyWith(enabled: on),
                      ),
                    )
                : null,
          ),
          for (final MapEntry<String, bool> engine
              in safeSearch.engines.entries)
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(
                left: Insets.xl,
                right: Insets.lg,
              ),
              title: Text(adguardHomeSearchEngineLabel(engine.key)),
              value: _shown('safesearch.${engine.key}', engine.value),
              onChanged: idle && safeSearchOn
                  ? (bool on) => _write(
                        'safesearch.${engine.key}',
                        on,
                        () => _actions.setSafeSearch(
                          before: safeSearch,
                          after: safeSearch.withEngine(engine.key, on: on),
                        ),
                      )
                  : null,
            ),
        ],
      ),
    );
  }
}
