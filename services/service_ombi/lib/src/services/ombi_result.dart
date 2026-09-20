import '../generated/generated.dart';

/// The data of a successful read, or an [OmbiException] saying what failed.
T requireData<T>(ApiResponse<T> response, String action) {
  final T? data = response.data;
  if (response.isSuccess && data != null) {
    return data;
  }
  throw _failure(response, action);
}

/// Checks a request mutation.
///
/// Ombi reports refusals, such as a title that is already requested, as HTTP
/// 200 with `isError` set, so a good status alone does not mean it worked.
void requireDone(ApiResponse<RequestEngineResult> response, String action) {
  if (!response.isSuccess) {
    throw _failure(response, action);
  }
  final RequestEngineResult? result = response.data;
  if (result?.isError ?? false) {
    throw OmbiException(
      _first(<String?>[result?.errorMessage, result?.message]) ??
          '$action failed',
      statusCode: response.statusCode,
    );
  }
}

OmbiException _failure(ApiResponse<dynamic> response, String action) =>
    OmbiException(
      _first(<String?>[
            response.error?.message,
            response.error?.description,
          ]) ??
          '$action failed',
      statusCode: response.statusCode,
      error: response.error,
    );

String? _first(List<String?> values) {
  for (final String? v in values) {
    final String? t = v?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
  }
  return null;
}
