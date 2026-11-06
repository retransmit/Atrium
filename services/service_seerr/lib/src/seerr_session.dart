import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// Which of Seerr's sign-in forms an account uses.
enum SeerrAccountKind {
  /// A local Seerr account, signed in with its email address.
  local,

  /// A Jellyfin or Emby account. Seerr has one endpoint for both and checks
  /// the password against whichever media server it is set up with.
  mediaServer,
}

/// The account a signed-in Seerr instance uses instead of the API key.
///
/// Stored in the instance's existing auth variants, so nothing new reaches the
/// profile store or the keystore: a local account is a `cookieLogin` holding
/// the email, and a Jellyfin or Emby account is a `userPass`. An API key
/// instance has no sign-in.
class SeerrSignIn {
  const SeerrSignIn({
    required this.kind,
    required this.username,
    required this.password,
  });

  final SeerrAccountKind kind;

  /// The email address for a local account, the username otherwise.
  final String username;
  final String password;

  static SeerrSignIn? fromAuth(InstanceAuth auth) => switch (auth) {
        InstanceAuthCookie(:final String username, :final String password) =>
          SeerrSignIn(
            kind: SeerrAccountKind.local,
            username: username,
            password: password,
          ),
        InstanceAuthUserPass(:final String username, :final String password) =>
          SeerrSignIn(
            kind: SeerrAccountKind.mediaServer,
            username: username,
            password: password,
          ),
        InstanceAuthApiKey() || InstanceAuthPlex() => null,
      };

  /// The auth to store for this account.
  InstanceAuth toAuth() => switch (kind) {
        SeerrAccountKind.local =>
          InstanceAuth.cookieLogin(username: username, password: password),
        SeerrAccountKind.mediaServer =>
          InstanceAuth.userPass(username: username, password: password),
      };
}

/// Builds the Dio a Seerr instance talks through.
///
/// An API key instance gets the factory's client as it is, since the key rides
/// every request. A signed-in instance also gets a cookie jar for Seerr's
/// session and a [SeerrSessionInterceptor] that signs in before the first
/// request and again when the session runs out.
Future<Dio> createSeerrDio(DioFactory factory, Instance instance) async {
  final Dio dio = await factory.create(instance);
  attachSeerrSession(dio, instance.auth);
  return dio;
}

/// Gives [dio] a Seerr session when [auth] is an account rather than a key.
void attachSeerrSession(Dio dio, InstanceAuth auth) {
  final SeerrSignIn? signIn = SeerrSignIn.fromAuth(auth);
  if (signIn == null) {
    return;
  }
  // The session interceptor goes first, so a request waits for the sign-in
  // and the cookie manager after it then attaches the fresh cookie.
  dio.interceptors
    ..add(SeerrSessionInterceptor(dio: dio, signIn: signIn))
    ..add(CookieManager(CookieJar()));
}

/// Keeps a Seerr session alive for a signed-in instance.
///
/// Seerr answers 403 both to a request without a valid session and to a user
/// who lacks the permission, and 401 to some permission failures as well. So
/// a refusal alone cannot tell an expired session from a forbidden action.
/// The interceptor asks `auth/me` which one it is: if the session still
/// stands the refusal is passed on as it is, and only otherwise does it sign
/// in again and send the request once more.
class SeerrSessionInterceptor extends Interceptor {
  SeerrSessionInterceptor({required Dio dio, required this.signIn})
      : _dio = dio;

  final Dio _dio;
  final SeerrSignIn signIn;

  /// Marks the interceptor's own requests, which must not wait on a sign-in.
  static const String _ownRequest = 'seerr.session.own';

  /// Marks a request already sent again after a fresh sign-in.
  static const String _retried = 'seerr.session.retried';

  /// The session a request was sent under.
  static const String _sentUnder = 'seerr.session.generation';

  /// Seerr's session cookie.
  static const String _sessionCookie = 'connect.sid';

  /// Counts sign-ins. Zero means no session yet.
  int _generation = 0;
  Future<void>? _signingIn;

  /// The answer to credentials Seerr refused, given from then on without
  /// asking again.
  ///
  /// The request list and issues poll every ten seconds, so retrying a wrong
  /// or stale password would send it over and over, and for a Jellyfin or
  /// Emby account Seerr passes every try on to the media server, which locks
  /// the account after a few (Jellyfin's default is three). Waiting between
  /// tries would only slow that down, since the count does not reset with
  /// time. The refusal lasts as long as this client, which is until the
  /// instance is edited or the app restarts.
  DioException? _refused;

  /// Signs in, sharing one attempt between every request waiting on it.
  Future<void> _signIn() {
    final DioException? refused = _refused;
    if (refused != null) {
      return Future<void>.error(refused);
    }
    return _signingIn ??= _postSignIn().whenComplete(() => _signingIn = null);
  }

  Future<void> _postSignIn() async {
    final bool local = signIn.kind == SeerrAccountKind.local;
    try {
      await _dio.post<dynamic>(
        local ? 'api/v1/auth/local' : 'api/v1/auth/jellyfin',
        // Only the credentials: Seerr refuses a Jellyfin sign-in that names a
        // hostname once its media server is set up.
        data: local
            ? <String, String>{
                'email': signIn.username,
                'password': signIn.password,
              }
            : <String, String>{
                'username': signIn.username,
                'password': signIn.password,
              },
        options: Options(extra: <String, dynamic>{_ownRequest: true}),
      );
      _generation++;
    } on DioException catch (e) {
      final DioException failure = _signInFailure(e);
      // Only the credentials being refused sticks. A network error or a
      // switched-off sign-in method can clear up by itself.
      final int? status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        _refused = failure;
      }
      throw failure;
    }
  }

  /// Rewrites a failed sign-in as the refusal it is.
  ///
  /// Seerr answers a wrong password with 401 or 403 and a switched-off sign-in
  /// method with a 500, none of which reads well raw. Every one is the
  /// account being refused, so each becomes a 401 whose message says why.
  DioException _signInFailure(DioException e) {
    final int? status = e.response?.statusCode;
    if (status == null) {
      return e;
    }
    final bool local = signIn.kind == SeerrAccountKind.local;
    final String? reason = _reason(e.response?.data);
    final String message = switch (status) {
      401 || 403 => local
          ? 'Seerr rejected the sign-in. Check the email and password.'
          : 'Seerr rejected the sign-in. Check the username and password, '
              'and that the account has been imported into Seerr or Seerr '
              'lets new Jellyfin and Emby users sign in.',
      _ when reason != null => 'Seerr refused the sign-in: $reason',
      _ => 'Seerr could not sign in (HTTP $status).',
    };
    return DioException(
      requestOptions: e.requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: e.requestOptions,
        statusCode: 401,
        data: <String, String>{'message': message},
      ),
    );
  }

  static String? _reason(Object? data) {
    if (data is Map) {
      for (final String key in <String>['error', 'message']) {
        final Object? value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_ownRequest] == true) {
      handler.next(options);
      return;
    }
    if (_generation == 0) {
      try {
        await _signIn();
      } on DioException catch (e) {
        handler.reject(e, true);
        return;
      }
    }
    options.extra[_sentUnder] = _generation;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final int? status = err.response?.statusCode;
    if ((status != 401 && status != 403) ||
        options.extra[_ownRequest] == true ||
        options.extra[_retried] == true) {
      handler.next(err);
      return;
    }
    try {
      final Object? sentUnder = options.extra[_sentUnder];
      // A sign-in since this request left means its session is already
      // replaced, so it only needs sending again.
      if (sentUnder == _generation) {
        if (await _sessionStands()) {
          handler.next(err);
          return;
        }
        await _signIn();
      }
      options.extra[_retried] = true;
      _dropSessionCookie(options);
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Whether the current session is still signed in.
  Future<bool> _sessionStands() async {
    try {
      await _dio.get<dynamic>(
        'api/v1/auth/me',
        options: Options(extra: <String, dynamic>{_ownRequest: true}),
      );
      return true;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return false;
      }
      rethrow;
    }
  }

  /// Takes the old session cookie off a request about to be sent again.
  ///
  /// The cookie manager keeps whatever the cookie header already holds and
  /// puts the jar's cookies after it, so the stale session would otherwise go
  /// first and be the one Seerr reads. Any other cookie, such as one set as a
  /// custom header for a proxy, stays.
  static void _dropSessionCookie(RequestOptions options) {
    final Object? header = options.headers[HttpHeaders.cookieHeader];
    if (header is! String) {
      return;
    }
    final String kept = header
        .split(';')
        .map((String c) => c.trim())
        .where((String c) => c.isNotEmpty && !c.startsWith('$_sessionCookie='))
        .join('; ');
    if (kept.isEmpty) {
      options.headers.remove(HttpHeaders.cookieHeader);
    } else {
      options.headers[HttpHeaders.cookieHeader] = kept;
    }
  }
}
