import 'track.dart';

class Playlist {
  final int id;
  final String title;
  final String cover;
  final int? numTracks;
  final List<Track> tracks;

  const Playlist({
    required this.id,
    required this.title,
    required this.cover,
    this.numTracks,
    this.tracks = const [],
  });

  factory Playlist.fromDeezer(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      title: json['title']?.toString() ?? 'Playlist',
      cover: json['picture_big']?.toString() ??
          json['picture_medium']?.toString() ??
          '',
      numTracks: json['nb_tracks'] as int?,
    );
  }

  Playlist copyWith({List<Track>? tracks}) => Playlist(
        id: id,
        title: title,
        cover: cover,
        numTracks: numTracks,
        tracks: tracks ?? this.tracks,
      );
}
