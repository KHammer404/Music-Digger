import 'package:equatable/equatable.dart';

class Artist extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;
  final List<String> aliases;
  final Map<String, int> platformTrackCounts; // e.g., {'youtube': 45, 'spotify': 30}

  const Artist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.aliases = const [],
    this.platformTrackCounts = const {},
  });

  int get totalTracks =>
      platformTrackCounts.values.fold(0, (sum, count) => sum + count);

  @override
  List<Object?> get props => [id, name, imageUrl, description, aliases, platformTrackCounts];
}
