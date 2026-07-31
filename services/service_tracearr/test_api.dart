import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse('http://localhost:8080/api/v1/stats/plays-by-hourofday'));
  // I need to add authorization, wait, I don't know the token.
  // Instead of fetching from API, let me just check the tracearr_home.dart output.
}
