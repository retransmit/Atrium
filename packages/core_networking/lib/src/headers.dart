/// Merges profile-wide and per-instance HTTP headers.
///
/// [instance] keys win over [global] keys on collision. Service auth
/// headers still win last overall because `AuthInterceptor` applies them
/// per-request, after these defaults.
Map<String, String> mergeHeaders(
  Map<String, String> global,
  Map<String, String> instance,
) =>
    <String, String>{...global, ...instance};
