import 'adguard_home_json.dart';

/// Who may use the server: `GET control/access/list`.
///
/// `POST control/access/set` replaces all three lists at once, so what was
/// read has to be sent back whole.
class AdguardHomeAccessList {
  const AdguardHomeAccessList({
    this.allowedClients = const <String>[],
    this.disallowedClients = const <String>[],
    this.blockedHosts = const <String>[],
  });

  factory AdguardHomeAccessList.fromJson(Map<String, dynamic> json) {
    return AdguardHomeAccessList(
      allowedClients: readStrings(json['allowed_clients']),
      disallowedClients: readStrings(json['disallowed_clients']),
      blockedHosts: readStrings(json['blocked_hosts']),
    );
  }

  /// Addresses, ranges and client ids. While this has anything in it, only
  /// these clients are answered.
  final List<String> allowedClients;

  /// Clients whose queries are dropped.
  final List<String> disallowedClients;

  /// Names the server refuses to resolve for anyone.
  final List<String> blockedHosts;

  /// Whether only the clients on the allowlist are answered.
  bool get allowlistInUse => allowedClients.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'allowed_clients': allowedClients,
        'disallowed_clients': disallowedClients,
        'blocked_hosts': blockedHosts,
      };
}

/// A client the server has settings for: its name and what it goes by.
class AdguardHomeClientRef {
  const AdguardHomeClientRef({required this.name, required this.ids});

  /// The named clients of `GET control/clients`.
  static List<AdguardHomeClientRef> listFromJson(Map<String, dynamic> json) {
    final Object? clients = json['clients'];
    if (clients is! List) return const <AdguardHomeClientRef>[];
    return <AdguardHomeClientRef>[
      for (final Object? client in clients)
        if (client is Map)
          AdguardHomeClientRef(
            name: readString(client['name']),
            ids: readStrings(client['ids']),
          ),
    ];
  }

  final String name;

  /// Addresses, ranges, MAC addresses and client ids.
  final List<String> ids;
}
