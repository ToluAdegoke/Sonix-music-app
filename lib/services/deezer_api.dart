import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class DeezerApi {
  static const String _base = 'https://api.deezer.com';

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Deezer API error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return [];
    final data =
    await _get('/search?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => (e['preview']?.toString().isNotEmpty ?? false))
        .map(Track.fromDeezer)
        .toList();
  }

  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get(
        '/search/artist?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(Artist.fromDeezer).toList();
  }

  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get(
        '/search/album?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(Album.fromDeezer).toList();
  }

  Future<List<Track>> getTopCharts({int limit = 25}) async {
    final data = await _get('/chart/0/tracks?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => (e['preview']?.toString().isNotEmpty ?? false))
        .map(Track.fromDeezer)
        .toList();
  }

  Future<List<Playlist>> getEditorialPlaylists({int limit = 15}) async {
    final data = await _get('/chart/0/playlists?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(Playlist.fromDeezer).toList();
  }

  Future<List<Album>> getTopAlbums({int limit = 15}) async {
    final data = await _get('/chart/0/albums?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(Album.fromDeezer).toList();
  }

  Future<List<Artist>> getTopArtists({int limit = 15}) async {
    final data = await _get('/chart/0/artists?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(Artist.fromDeezer).toList();
  }

  Future<List<Track>> getPlaylistTracks(int playlistId,
      {int limit = 50}) async {
    final data = await _get('/playlist/$playlistId/tracks?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => (e['preview']?.toString().isNotEmpty ?? false))
        .map(Track.fromDeezer)
        .toList();
  }

  Future<List<Track>> getAlbumTracks(int albumId) async {
    final data = await _get('/album/$albumId/tracks');
    final list = (data['data'] as List?) ?? [];

    // API response drops the main album payload here, fetching metadata to enrich tracks
    final albumInfo = await _get('/album/$albumId');
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => (e['preview']?.toString().isNotEmpty ?? false))
        .map((e) {
      e['album'] = {
        'id': albumInfo['id'],
        'title': albumInfo['title'],
        'cover_big': albumInfo['cover_big'],
        'cover_medium': albumInfo['cover_medium'],
      };
      return Track.fromDeezer(e);
    }).toList();
  }

  Future<List<Track>> getArtistTopTracks(int artistId, {int limit = 25}) async {
    final data = await _get('/artist/$artistId/top?limit=$limit');
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .where((e) => (e['preview']?.toString().isNotEmpty ?? false))
        .map(Track.fromDeezer)
        .toList();
  }
}