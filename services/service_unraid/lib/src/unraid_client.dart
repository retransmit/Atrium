import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/unraid_models.dart';

/// The disk fields Atrium reads, shared by the three lists the array splits
/// its disks across so none of them drifts out of step with the others.
const String _diskFields = 'idx name device type size status temp fsType '
    'isSpinning warning critical numErrors fsSize fsFree fsUsed';

/// Client for Unraid's GraphQL API.
///
/// Unraid is the only service Atrium talks to over GraphQL: one endpoint,
/// POST only, every query in the request body. Auth rides on the `x-api-key`
/// header, which the shared [AuthInterceptor] already sends for the api-key
/// style, so nothing extra is needed here.
///
/// The queries below were written against a live 7.3 server. The published
/// docs describe a flatter schema, with one list of disks and containers at
/// the top level, which does not match what is served.
class UnraidClient {
  UnraidClient(this._dio);

  final Dio _dio;

  static const String _endpoint = 'graphql';

  /// Runs [query] and returns its `data` object.
  ///
  /// GraphQL answers 200 even when it refuses the request, putting the reason
  /// in an `errors` array instead of the status line. Treating that as success
  /// is the classic way to end up rendering an empty screen and calling it
  /// healthy, so an errors array is raised here rather than passed on.
  Future<Map<String, dynamic>> _query(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        _endpoint,
        data: <String, dynamic>{
          'query': query,
          if (variables != null) 'variables': variables,
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final dynamic body = resp.data;
      if (body is! Map<String, dynamic>) {
        throw const NetworkUnknownException(
          'Unraid returned something other than a GraphQL response. Check the '
          'URL points at the server itself and not a proxy error page.',
        );
      }

      final dynamic errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        throw NetworkUnknownException(_describe(errors.first));
      }

      final dynamic data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw const NetworkUnknownException(
          'Unraid answered without any data.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Turns one GraphQL error into something worth showing.
  ///
  /// An API key without the right role gets `Forbidden resource`, which tells
  /// nobody what to do about it. Unraid keys carry per-resource permissions
  /// and a read-only key is a perfectly ordinary setup, so that case is named
  /// rather than passed through.
  static String _describe(Object? error) {
    if (error is! Map<String, dynamic>) {
      return error?.toString() ?? 'Unknown GraphQL error';
    }
    final String message =
        error['message']?.toString() ?? 'Unknown GraphQL error';
    final dynamic extensions = error['extensions'];
    final Object? code = extensions is Map<String, dynamic>
        ? extensions['code']
        : null;
    if (code == 'FORBIDDEN') {
      return 'This API key does not carry permission for that. Unraid keys '
          'are scoped per resource, so a key that can read the array may '
          'still be refused when changing anything.';
    }
    return message;
  }

  /// Array state, its disks, and how the last parity check went.
  ///
  /// The three disk lists are asked for separately because that is how the
  /// server keeps them: `disks` holds only the data disks, so a query for it
  /// alone silently loses every parity and cache disk.
  Future<UnraidArray> getArray() async {
    final Map<String, dynamic> data = await _query(
      '{ array { state '
      'capacity { kilobytes { free used total } } '
      'parityCheckStatus { status progress errors date duration correcting '
      'running paused } '
      'parities { $_diskFields } '
      'disks { $_diskFields } '
      'caches { $_diskFields } } }',
    );
    final dynamic array = data['array'];
    if (array is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid did not return an array. The API key may not carry the '
        'permission to read it.',
      );
    }
    return UnraidArray.fromJson(array);
  }

  /// Every Docker container the server knows about, running or not.
  ///
  /// A server with the Docker service stopped answers this with `Docker
  /// socket unavailable`, which reads as a fault in the app rather than a
  /// service someone turned off, so it is named here instead.
  Future<List<UnraidContainer>> getContainers() async {
    final Map<String, dynamic> data = await _containersQuery();
    final dynamic docker = data['docker'];
    if (docker is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid did not return any Docker data. The API key may not carry the '
        'permission to read it.',
      );
    }
    return (docker['containers'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(UnraidContainer.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> _containersQuery() async {
    try {
      return await _query(
        '{ docker { containers { id names image state status autoStart '
        'isOrphaned isUpdateAvailable iconUrl webUiUrl '
        'ports { privatePort publicPort type } } } }',
      );
    } on NetworkException catch (e) {
      if (e.message.toLowerCase().contains('docker socket')) {
        throw const NetworkUnknownException(
          'Docker is not running on this server. Start it under Settings, '
          'Docker, to manage containers from here.',
        );
      }
      rethrow;
    }
  }

  /// How hard the machine is working right now.
  ///
  /// One snapshot, not a series: the server keeps no history for these, so a
  /// graph has to be built by sampling. Memory here is in bytes, unlike the
  /// kilobytes the array reports for disks.
  Future<UnraidMetrics> getMetrics() async {
    final Map<String, dynamic> data = await _query(
      '{ metrics { '
      'cpu { percentTotal cpus { percentTotal percentUser percentSystem '
      'percentIdle } } '
      'memory { total used free available buffcache percentTotal swapTotal '
      'swapUsed percentSwapTotal } '
      'network { name operstate rxSec txSec } } }',
    );
    final dynamic metrics = data['metrics'];
    if (metrics is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid did not return any metrics. The API key may not carry the '
        'permission to read them.',
      );
    }
    return UnraidMetrics.fromJson(metrics);
  }

  /// The virtual machines, or word that there is no VM manager to ask.
  ///
  /// Unraid ships with virtualisation off and a server with it off does not
  /// answer this with an empty list, it refuses the query. That refusal is a
  /// normal state for most servers rather than a fault, so it is reported as
  /// one instead of being raised. It also has to be asked for on its own: an
  /// errors array anywhere in a response fails the whole request, so bundling
  /// this with the array or the containers would take those down too.
  Future<UnraidVmList> getVms() async {
    try {
      final Map<String, dynamic> data =
          await _query('{ vms { domains { id name state } } }');
      final dynamic vms = data['vms'];
      final dynamic domains =
          vms is Map<String, dynamic> ? vms['domains'] : null;
      if (domains is! List) {
        return const UnraidVmList(enabled: false);
      }
      return UnraidVmList(
        enabled: true,
        vms: domains
            .whereType<Map<String, dynamic>>()
            .map(UnraidVm.fromJson)
            .toList(),
      );
    } on NetworkException catch (e) {
      if (e.message.toLowerCase().contains('not available')) {
        return const UnraidVmList(enabled: false);
      }
      rethrow;
    }
  }

  Future<UnraidContainer> startContainer(String id) =>
      _containerAction('start', id);

  Future<UnraidContainer> stopContainer(String id) =>
      _containerAction('stop', id);

  Future<UnraidContainer> pauseContainer(String id) =>
      _containerAction('pause', id);

  Future<UnraidContainer> unpauseContainer(String id) =>
      _containerAction('unpause', id);

  /// Runs one of Docker's lifecycle mutations and reads back the result.
  ///
  /// [id] is the compound identifier the container list hands out, which pairs
  /// the server id with the container id; the bare Docker id is not accepted.
  ///
  /// The mutation returns the container in its new state, so that is used
  /// rather than refetching: the list takes a moment to catch up, and showing
  /// the old state right after acting reads as the action having failed.
  Future<UnraidContainer> _containerAction(String field, String id) async {
    final Map<String, dynamic> data = await _query(
      'mutation(\$id: PrefixedID!) { docker { $field(id: \$id) '
      '{ id names image state status autoStart isOrphaned isUpdateAvailable '
      'iconUrl webUiUrl ports { privatePort publicPort type } } } }',
      variables: <String, dynamic>{'id': id},
    );
    final dynamic docker = data['docker'];
    final dynamic result =
        docker is Map<String, dynamic> ? docker[field] : null;
    if (result is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid accepted the request but did not say what happened to the '
        'container.',
      );
    }
    return UnraidContainer.fromJson(result);
  }
}
