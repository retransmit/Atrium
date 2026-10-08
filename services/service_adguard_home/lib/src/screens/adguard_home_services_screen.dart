import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_services.dart';
import '../widgets/adguard_home_service_picker.dart';

/// Picks which services are blocked, out of the server's catalogue.
///
/// It writes nothing. Whatever is switched on when the screen is left, by
/// Done or by going back, is handed to whoever opened it: a switch that was
/// flipped is never lost to a back gesture.
class AdguardHomeServicesScreen extends ConsumerStatefulWidget {
  const AdguardHomeServicesScreen({
    required this.instance,
    required this.title,
    required this.selected,
    super.key,
  });

  final Instance instance;
  final String title;

  /// The ids of the services that are blocked when the screen opens.
  final Set<String> selected;

  @override
  ConsumerState<AdguardHomeServicesScreen> createState() =>
      _AdguardHomeServicesScreenState();
}

class _AdguardHomeServicesScreenState
    extends ConsumerState<AdguardHomeServicesScreen> {
  late Set<String> _selected = widget.selected;

  void _done() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeServiceCatalogue> catalogue =
        ref.watch(adguardHomeServicesProvider(widget.instance));
    return PopScope<Set<String>>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Set<String>? _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            TextButton(onPressed: _done, child: const Text('Done')),
            const SizedBox(width: Insets.sm),
          ],
        ),
        body: catalogue.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: ExpressiveProgressIndicator()),
          error: (Object error, StackTrace _) => SingleChildScrollView(
            child: ErrorView(
              message: describeAdguardHomeError(error),
              // After a refused sign-in this sends nothing: the session
              // answers for the server until the user asks to try again.
              onRetry: () =>
                  ref.invalidate(adguardHomeServicesProvider(widget.instance)),
            ),
          ),
          data: (AdguardHomeServiceCatalogue catalogue) =>
              AdguardHomeServicePicker(
            catalogue: catalogue,
            selected: _selected,
            onChanged: (Set<String> next) => setState(() => _selected = next),
          ),
        ),
      ),
    );
  }
}
