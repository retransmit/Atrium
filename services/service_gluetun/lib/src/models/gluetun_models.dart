// Data models for Gluetun HTTP control server API responses.

class GluetunVpnStatus {
  const GluetunVpnStatus({required this.status});

  factory GluetunVpnStatus.fromJson(Map<String, dynamic> json) {
    return GluetunVpnStatus(
      status: json['status']?.toString() ?? 'unknown',
    );
  }

  final String status;

  bool get isRunning => status.toLowerCase() == 'running';
  bool get isStopped => status.toLowerCase() == 'stopped';
}

class GluetunPublicIp {
  const GluetunPublicIp({
    required this.publicIp,
    this.region,
    this.country,
    this.city,
    this.organization,
  });

  factory GluetunPublicIp.fromJson(Map<String, dynamic> json) {
    return GluetunPublicIp(
      publicIp: json['public_ip']?.toString() ?? json['ip']?.toString() ?? '',
      region: json['region']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      organization: json['organization']?.toString(),
    );
  }

  final String publicIp;
  final String? region;
  final String? country;
  final String? city;
  final String? organization;

  /// [country], [region] and [city], leaving out blanks and repeats.
  ///
  /// A city-state reports the same name for all three, which read as
  /// "Singapore, Singapore, Singapore". A region or city is kept only when it
  /// names somewhere the larger places have not already named.
  GluetunPlaces get places {
    final String? country = _blankToNull(this.country);
    final String? region = _blankToNull(this.region);
    final String? city = _blankToNull(this.city);
    return (
      country: country,
      region: _samePlace(region, country) ? null : region,
      city: _samePlace(city, region) || _samePlace(city, country) ? null : city,
    );
  }
}

/// The places a public IP is in, as [GluetunPublicIp.places] returns them.
typedef GluetunPlaces = ({String? country, String? region, String? city});

String? _blankToNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _samePlace(String? a, String? b) =>
    a != null && b != null && a.toLowerCase() == b.toLowerCase();

class GluetunPortForward {
  const GluetunPortForward({
    required this.port,
    this.ports = const <int>[],
    this.status,
  });

  factory GluetunPortForward.fromJson(Map<String, dynamic> json) {
    final dynamic portVal = json['port'] ?? json['portforwarded'] ?? 0;
    final int portNum = portVal is int
        ? portVal
        : int.tryParse(portVal?.toString() ?? '') ?? 0;
    final Object? listed = json['ports'];
    final List<int> ports = <int>[
      if (listed is List)
        for (final Object? value in listed)
          if (_asPort(value) case final int port) port,
    ];
    return GluetunPortForward(
      port: portNum,
      ports: ports.isEmpty && _asPort(portNum) != null
          ? <int>[portNum]
          : ports,
      status: json['status']?.toString(),
    );
  }

  /// The first forwarded port, or 0 when nothing is forwarded.
  final int port;

  /// Every forwarded port, empty when nothing is forwarded yet.
  ///
  /// Current Gluetun lists them all under `ports`, and repeats the first as
  /// [port]; releases before v3.41 only send [port].
  final List<int> ports;

  final String? status;
}

int? _asPort(Object? value) {
  final int? port = value is int ? value : int.tryParse('$value');
  return port != null && port > 0 && port <= 65535 ? port : null;
}

class GluetunDnsStatus {
  const GluetunDnsStatus({required this.status});

  factory GluetunDnsStatus.fromJson(Map<String, dynamic> json) {
    return GluetunDnsStatus(
      status: json['status']?.toString() ?? 'unknown',
    );
  }

  final String status;

  bool get isRunning => status.toLowerCase() == 'running';
}

class GluetunUpdaterStatus {
  const GluetunUpdaterStatus({required this.status});

  factory GluetunUpdaterStatus.fromJson(Map<String, dynamic> json) {
    return GluetunUpdaterStatus(
      status: json['status']?.toString() ?? 'idle',
    );
  }

  final String status;

  bool get isRunning => status.toLowerCase() == 'running';
}
