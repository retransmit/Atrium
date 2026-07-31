import 'dart:convert';

void main() {
  final resData = {"activeStreams":2,"todayPlays":11,"todaySessions":11,"watchTimeHours":3.7,"alertsLast24h":0,"activeUsersToday":2};
  
  dynamic rawData = resData;
  Map<String, dynamic> data = <String, dynamic>{};
  if (rawData is Map) {
    data = Map<String, dynamic>.from(rawData);
  } else if (rawData is List && rawData.isNotEmpty) {
    final dynamic first = rawData.first;
    if (first is Map) {
      data = Map<String, dynamic>.from(first);
    }
  }
  
  if (data.containsKey('data')) {
    if (data['data'] is Map) {
      data = Map<String, dynamic>.from(data['data'] as Map);
    } else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
      final dynamic first = (data['data'] as List).first;
      if (first is Map) {
        data = Map<String, dynamic>.from(first);
      }
    }
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int activeStreams = parseInt(data['activeStreams'] ?? data['active_streams']);
  int todayPlays = parseInt(data['todayPlays'] ?? data['today_plays']);
  int todaySessions = parseInt(data['todaySessions'] ?? data['today_sessions']);
  double watchTimeHours = parseDouble(data['watchTimeHours'] ?? data['watch_time_hours']);
  int alertsLast24h = parseInt(data['alertsLast24h'] ?? data['alerts_last_24h']);
  int activeUsersToday = parseInt(data['activeUsersToday'] ?? data['active_users_today']);

  print('activeStreams: $activeStreams');
  print('todayPlays: $todayPlays');
  print('watchTimeHours: $watchTimeHours');
}
