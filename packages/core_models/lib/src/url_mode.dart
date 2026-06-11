/// How an [Instance] should pick between its LAN URL and WAN URL.
///
/// The default is [auto] - the connection layer probes the LAN URL with a
/// short timeout, caches the verdict per network fingerprint, and falls back
/// to the WAN URL on failure. The user can pin a specific URL per instance.
enum UrlMode {
  /// Probe LAN, fall back to WAN, cache the result per network.
  auto,

  /// Always use the LAN URL. Useful when only the LAN URL is reachable, or
  /// when the WAN URL is misconfigured but the user doesn't want to remove it
  /// outright.
  forceLocal,

  /// Always use the WAN URL. Useful when the user is permanently away from
  /// the LAN (e.g., a tablet that lives at a friend's house).
  forceExternal,
}
