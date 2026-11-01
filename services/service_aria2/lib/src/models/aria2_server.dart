import 'package:freezed_annotation/freezed_annotation.dart';

import 'aria2_json.dart';

part 'aria2_server.freezed.dart';
part 'aria2_server.g.dart';

/// Connected server info for a file inside a download (`aria2.getServers`).
@freezed
abstract class Aria2Server with _$Aria2Server {
  const factory Aria2Server({
    @JsonKey(fromJson: aria2Int) @Default(0) int index,
    @Default(<Aria2ServerConnection>[]) List<Aria2ServerConnection> servers,
  }) = _Aria2Server;

  factory Aria2Server.fromJson(Map<String, dynamic> json) =>
      _$Aria2ServerFromJson(json);
}

/// One connection to a server for a download.
@freezed
abstract class Aria2ServerConnection with _$Aria2ServerConnection {
  const factory Aria2ServerConnection({
    @Default('') String uri,
    @Default('') String currentUri,
    @JsonKey(fromJson: aria2Int) @Default(0) int downloadSpeed,
  }) = _Aria2ServerConnection;

  factory Aria2ServerConnection.fromJson(Map<String, dynamic> json) =>
      _$Aria2ServerConnectionFromJson(json);
}
