import 'adguard_home_client_edit.dart';
import 'models/adguard_home_clients.dart';
import 'models/adguard_home_stats.dart';

/// A persistent client with how much it asked.
class AdguardHomePersistentRow {
  const AdguardHomePersistentRow({required this.client, this.queries});

  final AdguardHomeClient client;

  /// Its queries in the period the statistics cover. Null when they say
  /// nothing of it: it is not among the top clients, or is left out of them.
  final int? queries;
}

/// A runtime client with how much it asked and whose it is.
class AdguardHomeRuntimeRow {
  const AdguardHomeRuntimeRow({
    required this.client,
    this.queries,
    this.owner,
  });

  final AdguardHomeRuntimeClient client;

  /// The queries from its address, where the statistics have them.
  final int? queries;

  /// The name of the persistent client the address belongs to, if any.
  final String? owner;
}

/// The clients of a server, as the Clients tab lists them.
class AdguardHomeClientsView {
  const AdguardHomeClientsView({
    this.persistent = const <AdguardHomePersistentRow>[],
    this.runtime = const <AdguardHomeRuntimeRow>[],
    this.supportedTags = const <String>[],
  });

  /// Puts together what three reads said: the clients, the top clients of
  /// the statistics, and what the server [found] when asked whose each of
  /// those is.
  ///
  /// A top client is an address or a ClientID. The server knows best whose
  /// it is: it can tell a device a client names by its MAC address. What it
  /// was not asked about, or could not be asked at all on a server without
  /// that lookup, is matched here instead (see [adguardHomeClientOwning]).
  ///
  /// Both lists come out with the most queries first.
  factory AdguardHomeClientsView.build({
    required AdguardHomeClientList list,
    List<AdguardHomeCount> topClients = const <AdguardHomeCount>[],
    Map<String, AdguardHomeFoundClient> found =
        const <String, AdguardHomeFoundClient>{},
  }) {
    final Map<String, int> byId = <String, int>{};
    final Map<String, int> byClient = <String, int>{};
    for (final AdguardHomeCount top in topClients) {
      final int queries = top.value.toInt();
      byId[top.name] = queries;
      final AdguardHomeClient? owner =
          adguardHomeOwnerOf(list.persistent, top.name, found[top.name]);
      if (owner != null) {
        byClient[owner.name] = (byClient[owner.name] ?? 0) + queries;
      }
    }

    return AdguardHomeClientsView(
      persistent: <AdguardHomePersistentRow>[
        for (final AdguardHomeClient client in list.persistent)
          AdguardHomePersistentRow(
            client: client,
            queries: byClient[client.name],
          ),
      ]..sort((AdguardHomePersistentRow a, AdguardHomePersistentRow b) {
          final int byQueries = _mostFirst(a.queries, b.queries);
          if (byQueries != 0) return byQueries;
          return a.client.name
              .toLowerCase()
              .compareTo(b.client.name.toLowerCase());
        }),
      runtime: <AdguardHomeRuntimeRow>[
        for (final AdguardHomeRuntimeClient client in list.runtime)
          AdguardHomeRuntimeRow(
            client: client,
            queries: byId[client.address],
            owner: adguardHomeOwnerOf(
              list.persistent,
              client.address,
              found[client.address],
            )?.name,
          ),
      ]..sort((AdguardHomeRuntimeRow a, AdguardHomeRuntimeRow b) {
          final int byQueries = _mostFirst(a.queries, b.queries);
          if (byQueries != 0) return byQueries;
          return _byAddress(a.client.address, b.client.address);
        }),
      supportedTags: list.supportedTags,
    );
  }

  final List<AdguardHomePersistentRow> persistent;
  final List<AdguardHomeRuntimeRow> runtime;

  /// The tags a client can be given.
  final List<String> supportedTags;
}

/// One client, looked up by an address or whatever else it goes by: what a
/// sheet needs to say who it is and what can be done with it.
class AdguardHomeClientLookup {
  const AdguardHomeClientLookup({
    required this.address,
    this.persistent,
    this.runtime,
    this.supportedTags = const <String>[],
    this.queries,
  });

  /// From the clients as read and, where the server was asked, what it
  /// [found] for [address].
  factory AdguardHomeClientLookup.of({
    required String address,
    required AdguardHomeClientList list,
    AdguardHomeFoundClient? found,
    int? queries,
  }) {
    AdguardHomeRuntimeClient? runtime;
    for (final AdguardHomeRuntimeClient client in list.runtime) {
      if (client.address == address) runtime = client;
    }
    final AdguardHomeClient? persistent =
        adguardHomeOwnerOf(list.persistent, address, found);
    // The list of runtime clients is what the server has on file. A lookup
    // can know more: it resolves the name and asks WHOIS when asked.
    if (runtime == null &&
        persistent == null &&
        found != null &&
        (found.name.isNotEmpty || found.whois.isNotEmpty)) {
      runtime = AdguardHomeRuntimeClient(
        address: address,
        name: found.name,
        whois: found.whois,
      );
    }
    return AdguardHomeClientLookup(
      address: address,
      persistent: persistent,
      runtime: runtime,
      supportedTags: list.supportedTags,
      queries: queries,
    );
  }

  /// What was looked up.
  final String address;

  /// The persistent client it belongs to, if any.
  final AdguardHomeClient? persistent;

  /// What the server knows of it as a runtime client, if anything.
  final AdguardHomeRuntimeClient? runtime;

  /// The tags a client can be given, for the form.
  final List<String> supportedTags;

  /// Its queries, where the caller knows them.
  final int? queries;

  /// What to call it: the persistent client's name, else the name the
  /// server found, else the address.
  String get title {
    final String? name = persistent?.name;
    if (name != null && name.isNotEmpty) return name;
    final String? seen = runtime?.name;
    if (seen != null && seen.isNotEmpty) return seen;
    return address;
  }
}

/// The persistent client that [id] belongs to.
///
/// With the server's answer for it, [found], that answer decides: a
/// persistent client comes back under its name with everything it goes by.
/// A runtime client can share a name with a persistent one, so the name
/// alone does not tell. Without an answer, the ids are matched here.
AdguardHomeClient? adguardHomeOwnerOf(
  List<AdguardHomeClient> clients,
  String id,
  AdguardHomeFoundClient? found,
) {
  if (found == null) return adguardHomeClientOwning(clients, id);
  for (final AdguardHomeClient client in clients) {
    if (client.name == found.name && _sameIds(client.ids, found.ids)) {
      return client;
    }
  }
  return null;
}

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final Set<String> ids = <String>{
    for (final String id in a) id.toLowerCase(),
  };
  return b.every((String id) => ids.contains(id.toLowerCase()));
}

/// Larger counts first, and no count last.
int _mostFirst(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Addresses by their number, not their spelling: the older kind before the
/// newer, and what is no address after both.
int _byAddress(String a, String b) {
  final List<int>? first = adguardHomeAddressBytes(a);
  final List<int>? second = adguardHomeAddressBytes(b);
  if (first == null || second == null) {
    if (first == null && second == null) return a.compareTo(b);
    return first == null ? 1 : -1;
  }
  if (first.length != second.length) {
    return first.length.compareTo(second.length);
  }
  for (int i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return first[i].compareTo(second[i]);
  }
  return a.compareTo(b);
}
