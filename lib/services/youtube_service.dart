import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  static final YoutubeService instance = YoutubeService._internal();
  YoutubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  Future<String?> getVideoId(String trackTitle, String artistName) async {
    try {
      final query = '$artistName $trackTitle official audio';
      print('[YouTube] Starting fetch for: $query');

      final searchList = await _yt.search.search(query);

      if (searchList.isEmpty) {
        print('[YouTube] No results found for query: $query');
        return null;
      }

      // Filter out massive mixes/podcasts, fallback to first result if none fit
      final video = searchList.firstWhere(
            (v) => v.duration != null && v.duration!.inMinutes < 15,
        orElse: () => searchList.first,
      );

      final videoId = video.id.value;
      print('[YouTube] Successfully found ID: $videoId');
      print('[YouTube] Video Title: ${video.title}');

      return videoId;

    } catch (e) {
      print('[YouTube] Search ERROR: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
    print('[YouTube] Service Disposed');
  }
}