import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/library_service.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _svc = LibraryService();

  List<Track> _liked = [];
  Map<String, List<Track>> _playlists = {};
  bool _loaded = false;

  List<Track> get likedTracks => List.unmodifiable(_liked);
  Map<String, List<Track>> get playlists => Map.unmodifiable(_playlists);
  bool get loaded => _loaded;

  Future<void> load() async {
    _liked = await _svc.loadLikedTracks();
    _playlists = await _svc.loadUserPlaylists();
    _loaded = true;
    notifyListeners();
  }

  bool isLiked(Track t) => _liked.any((x) => x.id == t.id);

  Future<void> toggleLike(Track t) async {
    if (isLiked(t)) {
      _liked.removeWhere((x) => x.id == t.id);
    } else {
      _liked.insert(0, t);
    }
    await _svc.saveLikedTracks(_liked);
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty || _playlists.containsKey(name)) return;
    _playlists[name] = [];
    await _svc.saveUserPlaylists(_playlists);
    notifyListeners();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    await _svc.saveUserPlaylists(_playlists);
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String name, Track t) async {
    final list = _playlists[name];
    if (list == null) return;
    if (!list.any((x) => x.id == t.id)) {
      list.add(t);
      await _svc.saveUserPlaylists(_playlists);
      notifyListeners();
    }
  }

  Future<void> removeTrackFromPlaylist(String name, Track t) async {
    final list = _playlists[name];
    if (list == null) return;
    list.removeWhere((x) => x.id == t.id);
    await _svc.saveUserPlaylists(_playlists);
    notifyListeners();
  }
}
