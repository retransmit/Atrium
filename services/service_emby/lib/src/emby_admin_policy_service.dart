import 'dart:convert';
import 'package:dio/dio.dart';

/// A dedicated service for updating Emby User Policies using the Admin API Key.
/// Strictly follows the Emby API requirements for folder restriction.
class EmbyAdminPolicyService {
  EmbyAdminPolicyService({
    required String baseUrl,
    required this.adminApiKey,
  }) {
    final String normalizedUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _dio = Dio(BaseOptions(baseUrl: normalizedUrl));
  }

  final String adminApiKey;
  late final Dio _dio;

  /// Restricts a user's access to specific libraries by name.
  Future<void> restrictUserToLibraries(String userId, List<String> targetLibraryNames) async {
    // Step 1: Fetch True Library GUIDs
    final Response<dynamic> foldersResp = await _dio.get<dynamic>(
      'Library/SelectableMediaFolders',
      options: Options(
        headers: <String, String>{
          'X-MediaBrowser-Token': adminApiKey,
          'Accept': 'application/json',
        },
      ),
    );

    final List<dynamic> folders = (foldersResp.data as List<dynamic>?) ?? <dynamic>[];
    final List<String> targetGuids = <String>[];
    int matchedLibraries = 0;

    for (final dynamic folder in folders) {
      final Map<String, dynamic> map = folder as Map<String, dynamic>;
      final String name = map['Name'] as String? ?? '';
      if (targetLibraryNames.contains(name)) {
        matchedLibraries++;
        final String? guid = map['Guid'] as String?;
        if (guid != null && guid.isNotEmpty) {
          targetGuids.add(guid);
        }
        
        // Emby's hidden API requirement: Also inject physical subfolder IDs
        final List<dynamic>? subFoldersList = map['SubFolders'] as List<dynamic>?;
        if (subFoldersList != null) {
          for (final dynamic subFolder in subFoldersList) {
            final Map<String, dynamic> subMap = subFolder as Map<String, dynamic>;
            final String subId = subMap['Id']?.toString() ?? subMap['Guid']?.toString() ?? '';
            if (subId.isNotEmpty && !targetGuids.contains(subId)) {
              targetGuids.add(subId);
            }
          }
        }
      }
    }

    if (matchedLibraries != targetLibraryNames.length) {
      throw Exception('Could not find true Guids for all requested libraries.');
    }

    // Step 2: Fetch Current User Policy (Read-Modify-Write)
    final Response<dynamic> userResp = await _dio.get<dynamic>(
      'Users/$userId',
      options: Options(
        headers: <String, String>{
          'X-MediaBrowser-Token': adminApiKey,
          'Accept': 'application/json',
        },
      ),
    );

    final Map<String, dynamic> rawUser = userResp.data as Map<String, dynamic>;
    final Map<String, dynamic> rawPolicy = rawUser['Policy'] as Map<String, dynamic>;

    // Step 3: Mutate the Policy
    rawPolicy['EnableAllFolders'] = false;
    rawPolicy['EnabledFolders'] = targetGuids;

    // Step 4: Post the Update
    await _dio.post<dynamic>(
      'Users/$userId/Policy',
      data: jsonEncode(rawPolicy),
      options: Options(
        headers: <String, String>{
          'X-MediaBrowser-Token': adminApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }
}
