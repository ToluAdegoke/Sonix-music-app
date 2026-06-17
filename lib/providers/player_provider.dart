import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';

/// Exposes AudioPlayerService as a ChangeNotifier for easy UI rebinding.
class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _svc = AudioPlayerService.instance;

  StreamSubscription? _trackSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _loadingSub;

  PlayerProvider() {
    // Listen for track changes (e.g., when the queue moves forward)
    _trackSub = _svc.currentTrackStream.listen((_) => notifyListeners());

    // Listen for play/pause state changes
    _playingSub = _svc.playingStream.listen((_) => notifyListeners());

    // NEW: Listen for YouTube loading/searching states
    _loadingSub = _svc.loadingStream.listen((_) => notifyListeners());
  }

  Track? get currentTrack => _svc.currentTrack;
  bool get isPlaying => _svc.isPlaying;

  /// Returns true if the service is currently hunting for the full YouTube version.
  /// Use this in your UI to show a loading spinner over the play button or track title.
  bool get isLoadingYoutube => _svc.isLoadingYoutube;

  List<Track> get queue => _svc.queue;
  AudioPlayerService get service => _svc;

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    await _svc.playQueue(tracks, startIndex: startIndex);
    notifyListeners();
  }

  Future<void> playSingle(Track track) => playTracks([track]);

  Future<void> togglePlay() async {
    await _svc.togglePlay();
    notifyListeners();
  }

  Future<void> next() async {
    await _svc.next();
    notifyListeners();
  }

  Future<void> previous() async {
    await _svc.previous();
    notifyListeners();
  }

  Future<void> seek(Duration d) => _svc.seek(d);

  @override
  void dispose() {
    _trackSub?.cancel();
    _playingSub?.cancel();
    _loadingSub?.cancel();
    super.dispose();
  }
}