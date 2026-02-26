import '../../domain/entities/track.dart';

class TrackModel {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final String? releaseDate;
  final List<TrackSourceModel> sources;

  TrackModel({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.durationSeconds,
    this.thumbnailUrl,
    this.releaseDate,
    this.sources = const [],
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artist_name'] as String,
      artistId: json['artist_id'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      releaseDate: json['release_date'] as String?,
      sources: (json['sources'] as List<dynamic>?)
              ?.map((s) => TrackSourceModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Track toEntity() {
    return Track(
      id: id,
      title: title,
      artistName: artistName,
      artistId: artistId,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      releaseDate: releaseDate,
      sources: sources.map((s) => s.toEntity()).toList(),
    );
  }
}

class TrackSourceModel {
  final String platform;
  final String platformTrackId;
  final String url;
  final String? thumbnailUrl;
  final int? viewCount;
  final bool isPlayable;

  TrackSourceModel({
    required this.platform,
    required this.platformTrackId,
    required this.url,
    this.thumbnailUrl,
    this.viewCount,
    this.isPlayable = true,
  });

  factory TrackSourceModel.fromJson(Map<String, dynamic> json) {
    return TrackSourceModel(
      platform: json['platform'] as String,
      platformTrackId: json['platform_track_id'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      viewCount: json['view_count'] as int?,
      isPlayable: json['is_playable'] as bool? ?? true,
    );
  }

  TrackSource toEntity() {
    return TrackSource(
      platform: platform,
      platformTrackId: platformTrackId,
      url: url,
      thumbnailUrl: thumbnailUrl,
      viewCount: viewCount,
      isPlayable: isPlayable,
    );
  }
}
