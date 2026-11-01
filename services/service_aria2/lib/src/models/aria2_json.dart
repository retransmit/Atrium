/// Readers for aria2's JSON-RPC payloads.
///
/// aria2's protocol has no number type: every numeric field in a
/// `tellStatus` / `getGlobalStat` reply is a *string* ("1234", "0", "true").
/// The RPC spec even says so outright - "it does not support floating point
/// numbers" - so a plain `json_serializable` int field would blow up on the
/// first real answer. These helpers accept either shape, which keeps the
/// models honest whether the server sent a number or its string form.
library;

/// Reads an integer that may arrive as a number or as a string.
int aria2Int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

/// Reads a boolean that may arrive as a bool or as the string "true"/"false".
bool aria2Bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.trim().toLowerCase() == 'true';
  }
  return false;
}

/// Reads a list of strings, skipping anything that is not one.
List<String> aria2StringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final dynamic item in value)
      if (item is String) item else item?.toString() ?? '',
  ];
}

/// Reads the display name out of a `bittorrent` struct.
///
/// aria2 nests the torrent's info dictionary two levels deep
/// (`bittorrent.info.name`), and the struct is absent entirely for anything
/// that is not a torrent.
String aria2TorrentName(Object? value) {
  if (value is! Map) {
    return '';
  }
  final Object? info = value['info'];
  if (info is! Map) {
    return '';
  }
  final Object? name = info['name'];
  return name is String ? name : '';
}

/// The last path segment of a file path, for both separators.
///
/// Windows servers report `C:\downloads\file.iso` and Linux ones
/// `/downloads/file.iso`; aria2 does not normalise them.
String aria2BaseName(String path) {
  if (path.isEmpty) {
    return '';
  }
  final int slash = path.lastIndexOf(RegExp(r'[/\\]'));
  return slash < 0 ? path : path.substring(slash + 1);
}
