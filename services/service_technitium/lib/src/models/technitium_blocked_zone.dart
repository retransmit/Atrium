import 'technitium_json.dart';

/// A blocked zone / domain configured in Technitium.
class TechnitiumBlockedZone {
  const TechnitiumBlockedZone({
    required this.domain,
    this.disabled = false,
  });

  factory TechnitiumBlockedZone.fromJson(Map<String, dynamic> json) {
    return TechnitiumBlockedZone(
      domain: readString(
        json['domain'] ?? json['zone'] ?? json['name'] ?? json['zoneName'],
      ),
      disabled: readBool(json['disabled']),
    );
  }

  final String domain;
  final bool disabled;
}
