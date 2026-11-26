import 'package:meta/meta.dart';

/// Host and port of an SSH server, parsed from an instance URL field.
///
/// A `ServiceKind.dockerHost` stores its addresses in the same local /
/// external URL fields every other service uses, so they may be written as
/// `ssh://host:port`, `host:port` or just `host`.
@immutable
class SshEndpoint {
  const SshEndpoint(this.host, [this.port = defaultPort]);

  static const int defaultPort = 22;

  final String host;
  final int port;

  /// Parses [raw], or returns null when it is empty or not an SSH address.
  static SshEndpoint? tryParse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(text.contains('://') ? text : 'ssh://$text');
    if (uri == null || uri.scheme.toLowerCase() != 'ssh' || uri.host.isEmpty) {
      return null;
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      return null;
    }
    // Read the port from the text: Uri drops an explicit `:0`.
    final RegExpMatch? explicit = RegExp(r':(\d+)/?$').firstMatch(text);
    final int port =
        explicit == null ? defaultPort : int.parse(explicit.group(1)!);
    if (port < 1 || port > 65535) {
      return null;
    }
    return SshEndpoint(uri.host, port);
  }

  @override
  bool operator ==(Object other) =>
      other is SshEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => host.contains(':') ? '[$host]:$port' : '$host:$port';
}
