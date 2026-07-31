import 'dart:convert';
import 'dart:io';

void main() async {
  final token = File('/data/user/0/app.atrium/app_flutter/tracearr_token.txt').readAsStringSync();
  print(token);
}
