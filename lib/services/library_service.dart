import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

/// Local persistence for liked songs + user-created playlists.
class LibraryService {
  static const _kLikedKey = 'sonix_liked_tracks_v1';
  static const _kPlaylistsKey = 'sonix_user_playlists_v1';

  Future<List<Track>> loadLikedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLikedKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(Track.fromJson)
        .toList();
  }

  Future<void> saveLikedTracks(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(tracks.map((t) => t.toJson()).toList());
    await prefs.setString(_kLikedKey, raw);
  }

  Future<Map<String, List<Track>>> loadUserPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaylistsKey);
    if (raw == null) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(
        k,
        (v as List)
            .cast<Map<String, dynamic>>()
            .map(Track.fromJson)
            .toList(),
      ),
    );
  }

  Future<void> saveUserPlaylists(Map<String, List<Track>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(
      playlists.map(
        (k, v) => MapEntry(k, v.map((t) => t.toJson()).toList()),
      ),
    );
    await prefs.setString(_kPlaylistsKey, raw);
  }
}
