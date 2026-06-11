/// Public surface of `core_models`.
///
/// Cross-cutting domain entities for Atrium. Services depend on this package
/// for shared types so the app shell can treat all services uniformly.
library;

export 'src/health.dart';
export 'src/instance.dart';
export 'src/instance_auth.dart';
export 'src/profile.dart';
export 'src/service_kind.dart';
export 'src/url_mode.dart';
