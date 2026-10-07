import 'package:core_networking/core_networking.dart';

/// AdGuard Home answered 401.
///
/// That is a wrong username or password, or an address it has locked out:
/// after five wrong sign-ins it refuses that address for fifteen minutes,
/// the right password included, and answers both cases identically.
class AdguardHomeSignInRefused implements Exception {
  const AdguardHomeSignInRefused();

  @override
  String toString() => 'AdGuard Home refused the sign-in.';
}

/// AdGuard Home turned a request down and said why, in its own words.
class AdguardHomeRequestRefused implements Exception {
  const AdguardHomeRequestRefused(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Something answered at this address, but not the way AdGuard Home does:
/// a proxy's sign-in page, or another server altogether.
class AdguardHomeUnexpectedAnswer implements Exception {
  const AdguardHomeUnexpectedAnswer();

  @override
  String toString() => 'This address answered, but not as AdGuard Home.';
}

/// The client is the only entry of the allowed clients, so it cannot be
/// shut out by taking it off: an empty list of allowed clients answers
/// everyone, which is the opposite of what was asked.
class AdguardHomeLastAllowedClient implements Exception {
  const AdguardHomeLastAllowedClient();

  static const String message =
      'This is the only allowed client. Taking it off the list would let '
      'every client in. Change the access settings in AdGuard Home instead.';

  @override
  String toString() => message;
}

/// The client is answered because an entry of the allowed clients covers
/// more than itself, a range or a client id, so there is no entry of its
/// own to take off.
class AdguardHomeAllowedByWiderEntry implements Exception {
  const AdguardHomeAllowedByWiderEntry();

  static const String message =
      'Only the allowed clients are answered, and this one is let in by an '
      'entry that covers more than itself, such as a range. It has no entry '
      'of its own to take off. Change the allowed clients in AdGuard Home '
      'instead.';

  @override
  String toString() => message;
}

/// One sentence for whatever went wrong, fit to show as it is.
String describeAdguardHomeError(Object error) => switch (error) {
      AdguardHomeSignInRefused() => 'AdGuard Home refused the sign-in.',
      AdguardHomeLastAllowedClient() => AdguardHomeLastAllowedClient.message,
      AdguardHomeAllowedByWiderEntry() =>
        AdguardHomeAllowedByWiderEntry.message,
      AdguardHomeRequestRefused(:final String message) => message,
      AdguardHomeUnexpectedAnswer() =>
        'This address answered, but not as AdGuard Home.',
      NetworkException(:final String message) => message,
      _ => 'Something went wrong talking to AdGuard Home.',
    };
