import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';

/// Pure helpers for running Docker commands over SSH.

/// Quotes [value] as a single POSIX shell word.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// Wraps [command] in a login shell so the host's profile sets `PATH` -
/// NAS distros (Synology, QNAP) keep `docker` in `/usr/local/bin`, which a
/// non-login exec channel does not see.
String loginShell(String command) => 'sh -lc ${shellQuote(command)}';

/// The exec command for an interactive shell inside [container]: bash when
/// the image has it, plain sh otherwise.
String dockerExecShellCommand(String container) {
  const String pickShell =
      'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi';
  return loginShell(
    'docker exec -it ${shellQuote(container)} sh -c ${shellQuote(pickShell)}',
  );
}

/// Lists running containers, one `name<TAB>image<TAB>status` per line.
final String dockerPsCommand =
    loginShell(r"docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'");

/// A running container as reported by `docker ps`.
@immutable
class DockerContainer {
  const DockerContainer({
    required this.name,
    required this.image,
    this.status = '',
  });

  final String name;
  final String image;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is DockerContainer &&
      other.name == name &&
      other.image == image &&
      other.status == status;

  @override
  int get hashCode => Object.hash(name, image, status);
}

/// Parses the output of [dockerPsCommand].
List<DockerContainer> parseDockerPs(String output) {
  final List<DockerContainer> result = <DockerContainer>[];
  for (final String line in output.split('\n')) {
    final List<String> parts = line.trimRight().split('\t');
    if (parts.first.trim().isEmpty) {
      continue;
    }
    result.add(
      DockerContainer(
        name: parts[0].trim(),
        image: parts.length > 1 ? parts[1].trim() : '',
        status: parts.length > 2 ? parts[2].trim() : '',
      ),
    );
  }
  return result;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Whether [container] looks like it runs [kind] (by name or image).
bool containerMatchesKind(DockerContainer container, ServiceKind kind) {
  final String token = _normalize(kind.name);
  return _normalize(container.name).contains(token) ||
      _normalize(container.image).contains(token);
}

/// [containers] with the ones that look like [kind] first, otherwise by name.
List<DockerContainer> rankContainersFor(
  ServiceKind kind,
  List<DockerContainer> containers,
) {
  return containers.sorted((DockerContainer a, DockerContainer b) {
    final int am = containerMatchesKind(a, kind) ? 0 : 1;
    final int bm = containerMatchesKind(b, kind) ? 0 : 1;
    return am != bm ? am - bm : a.name.compareTo(b.name);
  });
}

/// The Docker host [service]'s container runs on: the one it names, else the
/// profile's first Docker host. Null when the profile has none.
Instance? dockerHostFor(Instance service, List<Instance> instances) {
  final List<Instance> hosts = instances
      .where((Instance i) => i.kind == ServiceKind.dockerHost)
      .toList();
  if (service.dockerHostId.isNotEmpty) {
    final Instance? named =
        hosts.firstWhereOrNull((Instance h) => h.id == service.dockerHostId);
    if (named != null) {
      return named;
    }
  }
  return hosts.firstOrNull;
}

/// Plain words for a failed `docker` call, from its exit code and message.
String dockerIssueFor(int exitCode, String message) {
  final String m = message.toLowerCase();
  if (exitCode == 127 || m.contains('command not found')) {
    return 'Docker was not found on the host';
  }
  if (m.contains('permission denied') || exitCode == 126) {
    return 'This SSH user is not allowed to use Docker (needs sudo or '
        'the docker group)';
  }
  if (m.contains('cannot connect to the docker daemon') ||
      m.contains('is the docker daemon running')) {
    return 'Docker is installed but its daemon is not running';
  }
  return message.isEmpty ? 'Docker failed (exit $exitCode)' : message;
}

/// Applies the on-screen Ctrl / Alt modifiers to one chunk of terminal input,
/// the way a hardware keyboard would encode them.
String applyModifiers(String data, {bool ctrl = false, bool alt = false}) {
  String out = data;
  if (ctrl && out.length == 1) {
    final int c = out.codeUnitAt(0);
    if (c >= 0x61 && c <= 0x7a) {
      out = String.fromCharCode(c - 0x60);
    } else if (c >= 0x40 && c <= 0x5f) {
      // @ A-Z [ \ ] ^ _
      out = String.fromCharCode(c - 0x40);
    } else if (c == 0x20) {
      out = '\x00';
    } else if (c == 0x3f) {
      out = '\x7f';
    }
  }
  if (alt && out.isNotEmpty) {
    out = '\x1b$out';
  }
  return out;
}
