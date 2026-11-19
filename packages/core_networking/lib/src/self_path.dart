/// The request path that lands on [baseUrl] itself rather than beneath it.
///
/// [DioFactory] gives every base URL a trailing slash so relative paths join
/// onto it, so a service whose endpoint is the address itself, such as
/// rTorrent's XML-RPC, would be asked for at `.../action.php/` by an empty
/// path. nginx answers that with a 404, while Apache passes the slash on as
/// path info, which is how it went unnoticed. Below the root this is the
/// address without that slash; at the root it is the root, as before.
String selfPath(String baseUrl) {
  final Uri? uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.path.length <= 1 || !baseUrl.endsWith('/')) {
    return '';
  }
  return baseUrl.substring(0, baseUrl.length - 1);
}
