import 'dart:convert';
import 'dart:typed_data';

import 'adguard_home_json.dart';

/// A service the server can block as a whole: a name for a set of domains.
class AdguardHomeBlockedService {
  const AdguardHomeBlockedService({
    required this.id,
    required this.name,
    this.groupId = '',
    this.icon,
  });

  /// What the settings and the query log call it: `tiktok`.
  final String id;

  /// What a person calls it: TikTok.
  final String name;

  /// The group the server files it under, if any.
  final String groupId;

  /// Its icon, an SVG drawn in one colour. Null when the server sent none
  /// that can be read.
  final Uint8List? icon;
}

/// What `GET control/blocked_services/all` says: every service the server
/// can block, and the groups it sorts them into.
class AdguardHomeServiceCatalogue {
  const AdguardHomeServiceCatalogue({
    this.services = const <AdguardHomeBlockedService>[],
    this.groups = const <String>[],
  });

  factory AdguardHomeServiceCatalogue.fromJson(Map<String, dynamic> json) {
    final Object? services = json['blocked_services'];
    final Object? groups = json['groups'];
    return AdguardHomeServiceCatalogue(
      services: <AdguardHomeBlockedService>[
        if (services is List)
          for (final Object? service in services)
            if (service is Map<Object?, Object?>)
              if (readString(service['id']) case final String id)
                if (id.isNotEmpty)
                  AdguardHomeBlockedService(
                    id: id,
                    name: switch (readString(service['name'])) {
                      '' => id,
                      final String name => name,
                    },
                    groupId: readString(service['group_id']),
                    icon: _icon(service['icon_svg']),
                  ),
      ],
      groups: <String>[
        if (groups is List)
          for (final Object? group in groups)
            if (group is Map<Object?, Object?>)
              if (readString(group['id']) case final String id)
                if (id.isNotEmpty) id,
      ],
    );
  }

  final List<AdguardHomeBlockedService> services;

  /// The ids of the groups, in the server's order.
  final List<String> groups;

  /// The services filed under [groupId], in the server's order.
  List<AdguardHomeBlockedService> inGroup(String groupId) =>
      <AdguardHomeBlockedService>[
        for (final AdguardHomeBlockedService service in services)
          if (service.groupId == groupId) service,
      ];

  /// The name of the service with this [id], or the id when the catalogue
  /// has no such service.
  String nameOf(String id) {
    for (final AdguardHomeBlockedService service in services) {
      if (service.id == id) return service.name;
    }
    return id;
  }

  /// The server sends an icon as base64.
  static Uint8List? _icon(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}
