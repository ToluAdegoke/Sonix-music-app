/// A single track / song from the Deezer API.
class Track {
  final int id;
  final String title;
  final String artistName;
  final int? artistId;
  final String? albumTitle;
  final int? albumId;
  final String albumCover; // big cover (500x500)
  final String albumCoverSmall; // 250x250
  final String previewUrl; // 30-second MP3 preview
  final int durationSeconds;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.albumTitle,
    this.albumId,
    required this.albumCover,
    required this.albumCoverSmall,
    required this.previewUrl,
    required this.durationSeconds,
  });

  factory Track.fromDeezer(Map<String, dynamic> json) {
    final album = (json['album'] ?? {}) as Map<String, dynamic>;
    final artist = (json['artist'] ?? {}) as Map<String, dynamic>;
    return Track(
      id: json['id'] as int,
      title: json['title']?.toString() ?? 'Unknown',
      artistName: artist['name']?.toString() ?? 'Unknown Artist',
      artistId: artist['id'] as int?,
      albumTitle: album['title']?.toString(),
      albumId: album['id'] as int?,
      albumCover: album['cover_big']?.toString() ??
          album['cover_medium']?.toString() ??
          '',
      albumCoverSmall: album['cover_medium']?.toString() ??
          album['cover']?.toString() ??
          '',
      previewUrl: json['preview']?.toString() ?? '',
      durationSeconds: (json['duration'] ?? 30) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artistName': artistName,
        'artistId': artistId,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'albumCover': albumCover,
        'albumCoverSmall': albumCoverSmall,
        'previewUrl': previewUrl,
        'durationSeconds': durationSeconds,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as int,
        title: json['title'] as String,
        artistName: json['artistName'] as String,
        artistId: json['artistId'] as int?,
        albumTitle: json['albumTitle'] as String?,
        albumId: json['albumId'] as int?,
        albumCover: json['albumCover'] as String,
        albumCoverSmall: json['albumCoverSmall'] as String,
        previewUrl: json['previewUrl'] as String,
        durationSeconds: json['durationSeconds'] as int,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
