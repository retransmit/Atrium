import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_blocking.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../adguard_home_top_lists.dart';
import '../models/adguard_home_stats.dart';
import '../widgets/adguard_home_client_sheet.dart';
import '../widgets/adguard_home_top_list.dart';

/// Every row of one of the "top" lists.
///
/// It follows the statistics as they are re-read, as the Home tab does.
class AdguardHomeTopListScreen extends ConsumerWidget {
  const AdguardHomeTopListScreen({
    required this.instance,
    required this.kind,
    super.key,
  });

  final Instance instance;
  final AdguardHomeTopListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdguardHomeStats> stats =
        ref.watch(adguardHomeStatsProvider(instance));
    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      body: stats.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          message: describeAdguardHomeError(error),
          // Reads again without telling the session to let a request out:
          // after a refused sign-in this sends nothing.
          onRetry: () => ref.invalidate(adguardHomeStatsProvider(instance)),
        ),
        data: (AdguardHomeStats stats) {
          final List<AdguardHomeCount> rows = kind.rows(stats);
          if (rows.isEmpty) return const EmptyView(title: 'Nothing yet');
          final num highest = adguardHomeHighest(rows);
          return ListView.builder(
            padding: Insets.page,
            itemCount: rows.length,
            itemBuilder: (BuildContext _, int index) => AdguardHomeTopRow(
              kind: kind,
              row: rows[index],
              highest: highest,
              onBlocking: (String domain, {required bool block}) =>
                  adguardHomeToggleBlocking(
                context,
                ref,
                instance,
                domain,
                block: block,
              ),
              onOpen: kind == AdguardHomeTopListKind.clients
                  ? () => showAdguardHomeClientSheet(
                        context,
                        instance: instance,
                        address: rows[index].name,
                        queries: rows[index].value.toInt(),
                      )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
