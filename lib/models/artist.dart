class Artist {
  final int id;
  final String name;
  final String picture;
  final int? numFans;

  const Artist({
    required this.id,
    required this.name,
    required this.picture,
    this.numFans,
  });

  factory Artist.fromDeezer(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      picture: json['picture_big']?.toString() ??
          json['picture_medium']?.toString() ??
          '',
      numFans: json['nb_fan'] as int?,
    );
  }
}
