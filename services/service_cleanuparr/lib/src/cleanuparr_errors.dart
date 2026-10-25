import 'package:core_networking/core_networking.dart';

/// What to show for a failed request: a [NetworkException]'s own message,
/// without its type name.
String describeCleanuparrError(Object error) =>
    error is NetworkException ? error.message : '$error';
