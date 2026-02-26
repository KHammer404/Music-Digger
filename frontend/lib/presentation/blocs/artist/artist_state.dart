import 'package:equatable/equatable.dart';

import '../../../domain/entities/artist.dart';
import '../../../domain/entities/track.dart';
import '../home/home_state.dart';

enum ArtistStatus { initial, loading, loaded, error }

class ArtistState extends Equatable {
  final ArtistStatus status;
  final Artist? artist;
  final List<Track> tracks;
  final int totalTracks;
  final List<RecommendedArtist> similarArtists;
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
      errorMessage: errorMessage,
      error: error,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [status, artist, tracks, totalTracks, similarArtists, errorMessage, isLoadingMore, hasReachedMax];
}
