import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicService {
  // Singleton setup
  MusicService._internal();
  static final MusicService instance = MusicService._internal();

  String _activeBaseUrl = "";

  void updateBaseUrl(String newUrl) {
    _activeBaseUrl = newUrl.split('/play')[0];
    print('[MusicService] 🔗 Search API updated to: $_activeBaseUrl');
  }

  // Updated search method to return data for the UI
  Future<Map<String, dynamic>?> searchYoutube(String query) async {
    if (_activeBaseUrl.isEmpty) return null;

    try {
      final url = Uri.parse('$_activeBaseUrl/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Search error: $e');
    }
    return null;
  }
}