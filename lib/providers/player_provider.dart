import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _svc = AudioPlayerService.instance;

  StreamSubscription? _trackSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _loadingSub;

  PlayerProvider() {
    _trackSub = _svc.currentTrackStream.listen((_) => notifyListeners());
    _playingSub = _svc.playingStream.listen((_) => notifyListeners());
    _loadingSub = _svc.loadingStream.listen((_) => notifyListeners());
  }

  Track? get currentTrack => _svc.currentTrack;
  bool get isPlaying => _svc.isPlaying;
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