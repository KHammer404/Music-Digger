import '../../domain/entities/artist.dart';

class ArtistModel {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;
  final List<String> aliases;
  final Map<String, int> platformTrackCounts;

  ArtistModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.aliases = const [],
    this.platformTrackCounts = const {},
  });

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? [],
      platformTrackCounts: (json['platform_track_counts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'description': description,
      'aliases': aliases,
      'platform_track_counts': platformTrackCounts,
    };
  }

  Artist toEntity() {
    return Artist(
      id: id,
      name: name,
      imageUrl: imageUrl,
      description: description,
      aliases: aliases,
      platformTrackCounts: platformTrackCounts,
    );
  }
}
