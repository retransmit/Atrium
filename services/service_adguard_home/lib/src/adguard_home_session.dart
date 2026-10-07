import 'dart:async';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'adguard_home_errors.dart';

/// Lets requests to one AdGuard Home out one at a time, and stops sending
/// altogether once the server has refused the sign-in.
///
/// AdGuard Home refuses an address for fifteen minutes after five wrong
/// sign-ins, and while it does, the right password gets the same bare 401
/// as a wrong one. Every signed request counts. So a wrong password must
/// cost one request, not one per thing a screen happens to be loading, and
/// it must not be retried on a timer:
///
///  * requests queue, so when the first is refused the ones behind it fail
///    without being sent;
///  * after a refusal nothing is sent at all until [retry], which the user
///    asks for, and which costs one more request.
class AdguardHomeSession {
  bool _refused = false;
  int _refusals = 0;
  Future<void> _tail = Future<void>.value();

  /// Whether the server has refused the sign-in, so nothing is being sent.
  bool get refused => _refused;

  /// How many sign-ins the server has refused in a row. Each was a request
  /// that reached it, so each counted towards its lockout. Back to zero at
  /// the next answer.
  ///
  /// The screens show this beside Try again: without it a try that is
  /// refused again looks exactly like no try at all, and the fifth one in a
  /// row is the one that gets the address blocked.
  int get refusals => _refusals;

  /// Lets the next request out. Call it when the user asks to try again.
  void retry() => _refused = false;

  /// Runs [request] once every earlier one has finished.
  ///
  /// A 401 becomes [AdguardHomeSignInRefused] and closes the session. A
  /// request the server turned down with a reason becomes
  /// [AdguardHomeRequestRefused]. Any other HTTP failure becomes a
  /// [NetworkException].
  Future<T> run<T>(Future<T> Function() request) {
    final Completer<T> done = Completer<T>();
    _tail = _tail.then((void _) async {
      if (_refused) {
        done.completeError(
          const AdguardHomeSignInRefused(),
          StackTrace.current,
        );
        return;
      }
      try {
        final T answer = await request();
        _refusals = 0;
        done.complete(answer);
      } on DioException catch (error, stack) {
        if (error.response?.statusCode == 401) {
          _refused = true;
          _refusals++;
          done.completeError(const AdguardHomeSignInRefused(), stack);
        } else {
          done.completeError(_failure(error), stack);
        }
      } on Object catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// AdGuard Home explains a request it turns down in one line of plain
  /// text. A page of markup with the same status is some other server.
  static Object _failure(DioException error) {
    final Response<dynamic>? response = error.response;
    final int status = response?.statusCode ?? 0;
    final Object? body = response?.data;
    final String type =
        response?.headers.value(Headers.contentTypeHeader) ?? '';
    if (status >= 400 &&
        status < 500 &&
        type.startsWith('text/plain') &&
        body is String &&
        body.trim().isNotEmpty) {
      return AdguardHomeRequestRefused(body.trim());
    }
    return NetworkException.fromDio(error);
  }
}
