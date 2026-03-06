import 'package:equatable/equatable.dart';

import '../../../domain/entities/artist.dart';
import '../../../domain/entities/track.dart';
import '../home/home_state.dart';

enum ArtistStatus { initial, loading, loaded, error }

class PlatformPresence extends Equatable {
  final String platform;
  final String platformId;
  final String name;
  final String? url;
  final String? imageUrl;
  final int? followerCount;

  const PlatformPresence({
    required this.platform,
    required this.platformId,
    required this.name,
    this.url,
    this.imageUrl,
    this.followerCount,
  });

  factory PlatformPresence.fromJson(Map<String, dynamic> json) {
    return PlatformPresence(
      platform: json['platform'] as String? ?? '',
      platformId: json['platform_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
      imageUrl: json['image_url'] as String?,
      followerCount: json['follower_count'] as int?,
    );
  }

  @override
  List<Object?> get props => [platform, platformId];
}

class ArtistState extends Equatable {
  final ArtistStatus status;
  final Artist? artist;
  final List<Track> tracks;
  final int totalTracks;
  final List<RecommendedArtist> similarArtists;
  final List<PlatformPresence> platformPresences;
  final String? errorMessage;
  final Object? error;
  final bool isLoadingMore;
  final bool hasReachedMax;

  const ArtistState({
    this.status = ArtistStatus.initial,
    this.artist,
    this.tracks = const [],
    this.totalTracks = 0,
    this.similarArtists = const [],
    this.platformPresences = const [],
    this.errorMessage,
    this.error,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
  });

  ArtistState copyWith({
    ArtistStatus? status,
    Artist? artist,
    List<Track>? tracks,
    int? totalTracks,
    List<RecommendedArtist>? similarArtists,
    List<PlatformPresence>? platformPresences,
    String? errorMessage,
    Object? error,
    bool? isLoadingMore,
    bool? hasReachedMax,
  }) {
    return ArtistState(
      status: status ?? this.status,
      artist: artist ?? this.artist,
      tracks: tracks ?? this.tracks,
      totalTracks: totalTracks ?? this.totalTracks,
      similarArtists: similarArtists ?? this.similarArtists,
      platformPresences: platformPresences ?? this.platformPresences,
      errorMessage: errorMessage,
      error: error,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [status, artist, tracks, totalTracks, similarArtists, platformPresences, errorMessage, isLoadingMore, hasReachedMax];
}
