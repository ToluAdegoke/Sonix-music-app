class Album {
  final int id;
  final String title;
  final String artistName;
  final String cover;

  const Album({
    required this.id,
    required this.title,
    required this.artistName,
    required this.cover,
  });

  factory Album.fromDeezer(Map<String, dynamic> json) {
    final artist = (json['artist'] ?? {}) as Map<String, dynamic>;
    return Album(
      id: json['id'] as int,
      title: json['title']?.toString() ?? 'Unknown',
      artistName: artist['name']?.toString() ?? '',
      cover: json['cover_big']?.toString() ??
          json['cover_medium']?.toString() ??
          '',
    );
  }
}
