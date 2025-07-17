import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> fetchReleaseNotes() async {
  final response = await http.get(Uri.parse('https://api.github.com/repos/imnexerio/revix/releases/latest'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['body'] ?? 'No release notes available';
  } else {
    throw Exception('Failed to load release notes');
  }
}