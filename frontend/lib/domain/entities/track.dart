import 'package:equatable/equatable.dart';

class Track extends Equatable {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final String? releaseDate;
  final List<TrackSource> sources;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.durationSeconds,
    this.thumbnailUrl,
    this.releaseDate,
    this.sources = const [],
  });

  String get durationFormatted {
    if (durationSeconds == null) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  TrackSource? get bestSource {
    if (sources.isEmpty) return null;
    // Priority: Spotify > YouTube > SoundCloud > others
    const priority = ['spotify', 'youtube', 'soundcloud', 'niconico', 'bandcamp'];
    for (final platform in priority) {
      final source = sources.where((s) => s.platform == platform).firstOrNull;
      if (source != null && source.isPlayable) return source;
    }
    return sources.first;
  }

  @override
  List<Object?> get props => [id, title, artistName, durationSeconds, sources];
}

class TrackSource extends Equatable {
  final String platform;
  final String platformTrackId;
  final String url;
  final String? thumbnailUrl;
  final int? viewCount;
  final bool isPlayable;

  const TrackSource({
    required this.platform,
    required this.platformTrackId,
    required this.url,
    this.thumbnailUrl,
    this.viewCount,
    this.isPlayable = true,
  });

  @override
  List<Object?> get props => [platform, platformTrackId, url];
}
