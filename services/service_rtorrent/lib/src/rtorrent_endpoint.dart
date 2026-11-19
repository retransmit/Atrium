import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'rtorrent_api.dart';

/// What answered when rTorrent's XML-RPC was asked for at an address.
enum RtorrentEndpointAnswer {
  /// rTorrent itself: the call came back as XML-RPC.
  xmlRpc,

  /// The proxy in front refused the credentials.
  refused,

  /// Something answered, but not with XML-RPC: a web page such as ruTorrent's
  /// own, a 404, or a proxy error.
  notXmlRpc,

  /// Nothing answered at all.
  unreachable,
}

/// Where rTorrent's XML-RPC usually lives beneath the address a user types.
///
/// Most seedboxes run ruTorrent in front of rTorrent and reach it only through
/// ruTorrent's httprpc plugin, which passes XML-RPC straight through. The
/// address people have to hand is the ruTorrent page, or the box's root with
/// ruTorrent under it. Self-hosted setups more often mount it at `/RPC2`.
const List<String> rtorrentEndpointGuesses = <String>[
  'plugins/httprpc/action.php',
  'rutorrent/plugins/httprpc/action.php',
  'RPC2',
];

/// Asks the XML-RPC at [dio]'s base URL for rTorrent's version.
Future<RtorrentEndpointAnswer> checkRtorrentEndpoint(Dio dio) async {
  try {
    await RtorrentApi(dio).clientVersion();
    return RtorrentEndpointAnswer.xmlRpc;
  } on NetworkAuthException {
    return RtorrentEndpointAnswer.refused;
  } on NetworkServerException catch (e) {
    // A fault rides inside a 200, and only rTorrent sends one.
    return e.status == 200
        ? RtorrentEndpointAnswer.xmlRpc
        : RtorrentEndpointAnswer.notXmlRpc;
  } on NetworkBadResponseException {
    return RtorrentEndpointAnswer.notXmlRpc;
  } on NetworkNotFoundException {
    return RtorrentEndpointAnswer.notXmlRpc;
  } on NetworkException {
    return RtorrentEndpointAnswer.unreachable;
  }
}

/// [url] with [path] appended, or null when [url] already points at an
/// endpoint and there is nothing to look for beneath it.
String? rtorrentGuessUrl(String url, String path) {
  final String base = url.trim().replaceFirst(RegExp(r'/+$'), '');
  final String last = base.split('/').last.toLowerCase();
  if (last.endsWith('.php') || last == 'rpc2') {
    return null;
  }
  return '$base/$path';
}
