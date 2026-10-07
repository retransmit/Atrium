import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adguard_home_api.dart';
import 'adguard_home_providers.dart';
import 'models/adguard_home_query_log.dart';

/// What the Query log tab has to show.
class AdguardHomeQueryLogState {
  const AdguardHomeQueryLogState({
    this.entries = const <AdguardHomeQueryLogEntry>[],
    this.search = '',
    this.filter = AdguardHomeLogFilter.all,
    this.loading = false,
    this.loadingMore = false,
    this.reachedEnd = false,
    this.stalled = false,
    this.searchedBackTo = '',
    this.error,
  });

  /// Newest first.
  final List<AdguardHomeQueryLogEntry> entries;

  /// What the list is searched for, trimmed. Empty for no search.
  final String search;
  final AdguardHomeLogFilter filter;

  /// Whether the list is being read from the top.
  final bool loading;

  /// Whether older entries are being read.
  final bool loadingMore;

  /// Whether the server said there is nothing older.
  final bool reachedEnd;

  /// Whether the last read spent its requests without filling a page or
  /// reaching the end: a rare match in a long log. Going on is then left to
  /// the user rather than done in a loop.
  final bool stalled;

  /// Where the server stopped, in its own writing. The next read goes on
  /// from here.
  final String searchedBackTo;

  /// Why the last read failed, or null when it did not. With [entries]
  /// empty the list could not be read at all; otherwise only the older
  /// entries could not.
  final Object? error;

  /// Whether a search or a filter is narrowing the list.
  bool get narrowed => search.isNotEmpty || filter != AdguardHomeLogFilter.all;

  /// Whether older entries should be asked for as the end of the list comes
  /// into view. Not after a failure and not while [stalled]: those wait to
  /// be asked.
  bool get wantsMore =>
      !loading && !loadingMore && !reachedEnd && !stalled && error == null;

  AdguardHomeQueryLogState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? stalled,
    bool clearError = false,
  }) {
    return AdguardHomeQueryLogState(
      entries: entries,
      search: search,
      filter: filter,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      reachedEnd: reachedEnd,
      stalled: stalled ?? this.stalled,
      searchedBackTo: searchedBackTo,
      error: clearError ? null : error,
    );
  }
}

/// The query log of an instance, a page at a time, under a search and a
/// filter. It is read when the Query log tab is first shown and not before.
final adguardHomeQueryLogProvider = NotifierProvider.autoDispose
    .family<AdguardHomeQueryLog, AdguardHomeQueryLogState, Instance>(
  AdguardHomeQueryLog.new,
);

class AdguardHomeQueryLog extends Notifier<AdguardHomeQueryLogState> {
  AdguardHomeQueryLog(this.instance);

  final Instance instance;

  /// How many requests one read may send.
  ///
  /// Under a filter the server gives up scanning after a while and answers
  /// with what it has and how far it got, so one page can take several
  /// requests. With a rare match in a log of months that would otherwise
  /// run to hundreds of them, each a scan on the server.
  static const int requestsPerRead = 5;

  /// Counts the reads that were started. The answer to any but the latest
  /// is thrown away: the search or the filter has changed under it.
  int _read = 0;

  /// Whether the screen that watched this list is gone. The end of the list
  /// asks for more a frame after it is drawn, and the search box a moment
  /// after the typing, so a call can arrive after that. It is then dropped.
  bool get _gone => !ref.mounted;

  @override
  AdguardHomeQueryLogState build() {
    ref.onDispose(() => _read++);
    Future<void>.microtask(() => _readFrom(top: true));
    return const AdguardHomeQueryLogState(loading: true);
  }

  /// Reads the newest entries again under the same search and filter. What
  /// is shown stays until the answer is in.
  Future<void> reload() {
    if (_gone) return Future<void>.value();
    state = state.copyWith(loading: true, loadingMore: false);
    return _readFrom(top: true);
  }

  /// Reads the entries older than the ones held.
  Future<void> loadMore() {
    if (_gone || state.loading || state.loadingMore || state.reachedEnd) {
      return Future<void>.value();
    }
    state = state.copyWith(loadingMore: true, stalled: false, clearError: true);
    return _readFrom(top: false);
  }

  /// Searches the log for [text], in domains and clients. In double quotes
  /// it has to match whole.
  Future<void> setSearch(String text) {
    final String search = text.trim();
    if (_gone || search == state.search) return Future<void>.value();
    return _narrow(search, state.filter);
  }

  Future<void> setFilter(AdguardHomeLogFilter filter) {
    if (_gone || filter == state.filter) return Future<void>.value();
    return _narrow(state.search, filter);
  }

  /// Drops the search and the filter at once, as one read.
  Future<void> clearNarrowing() {
    if (_gone || !state.narrowed) return Future<void>.value();
    return _narrow('', AdguardHomeLogFilter.all);
  }

  /// What was shown answered another question, so it goes at once.
  Future<void> _narrow(String search, AdguardHomeLogFilter filter) {
    state = AdguardHomeQueryLogState(
      search: search,
      filter: filter,
      loading: true,
    );
    return _readFrom(top: true);
  }

  Future<void> _readFrom({required bool top}) async {
    if (_gone) return;
    final int read = ++_read;
    final String search = state.search;
    final AdguardHomeLogFilter filter = state.filter;
    final List<AdguardHomeQueryLogEntry> found = <AdguardHomeQueryLogEntry>[];
    String cursor = top ? '' : state.searchedBackTo;
    bool end = false;
    Object? failure;

    try {
      final AdguardHomeApi api =
          await ref.read(adguardHomeApiProvider(instance).future);
      for (int request = 0; request < requestsPerRead; request++) {
        final AdguardHomeQueryLogPage page = await api.getQueryLog(
          olderThan: cursor,
          search: search,
          filter: filter,
        );
        if (read != _read) return;
        found.addAll(page.entries);
        if (page.isEnd) {
          end = true;
          break;
        }
        cursor = page.oldest;
        if (found.length >= AdguardHomeApi.queryLogPageSize) break;
      }
    } on Object catch (error) {
      failure = error;
    }
    if (read != _read) return;

    state = AdguardHomeQueryLogState(
      // What was found before a failure is kept: the next read goes on from
      // where the last good answer stopped.
      entries: top
          ? found
          : <AdguardHomeQueryLogEntry>[...state.entries, ...found],
      search: search,
      filter: filter,
      reachedEnd: end,
      stalled: failure == null &&
          !end &&
          found.length < AdguardHomeApi.queryLogPageSize,
      searchedBackTo: cursor,
      error: failure,
    );
  }
}

/// Whether the server keeps a query log at all. Read once, and only by
/// whoever needs to explain an empty one.
final adguardHomeQueryLogConfigProvider =
    FutureProvider.autoDispose.family<AdguardHomeQueryLogConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final AdguardHomeApi api =
      await ref.watch(adguardHomeApiProvider(instance).future);
  return api.getQueryLogConfig();
});
