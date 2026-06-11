/// Route paths and names for Atrium navigation.
///
/// Centralizing these as constants keeps `context.goNamed(...)` calls
/// type-checked-ish (no stringly-typed paths scattered around) and gives one
/// place to see the whole navigation surface.
///
/// The actual [GoRouter] is assembled in the app layer (where all screens are
/// in scope); this package owns the vocabulary and the nav shell.
abstract final class AtriumRoutes {
  // Bottom-nav branches.
  static const String dashboard = '/dashboard';
  static const String dashboardName = 'dashboard';

  static const String library = '/library';
  static const String libraryName = 'library';

  static const String activity = '/activity';
  static const String activityName = 'activity';

  static const String settings = '/settings';
  static const String settingsName = 'settings';

  // Instance management (pushed over the shell).
  static const String addInstance = 'add-instance';
  static const String addInstanceName = 'add-instance';

  static const String editInstance = 'edit-instance/:instanceId';
  static const String editInstanceName = 'edit-instance';

  static const String profiles = 'profiles';
  static const String profilesName = 'profiles';

  /// Service detail route, parameterized by service kind and instance id -
  /// e.g. `/dashboard/service/sonarr/9f3b...`. Each service module renders
  /// its own screen for the matched kind.
  static const String service = 'service/:kind/:instanceId';
  static const String serviceName = 'service';

  /// Builds the path to a service detail screen under the dashboard branch.
  static String servicePath(String kind, String instanceId) =>
      '$dashboard/service/$kind/$instanceId';
}
