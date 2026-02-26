import 'package:equatable/equatable.dart';

import '../../../domain/entities/artist.dart';
import '../../../domain/entities/track.dart';

enum SearchStatus { initial, loading, loaded, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final List<Artist> artists;
  final List<Track> tracks;
  final Set<String> selectedPlatforms;
  final int totalArtists;
  final int totalTracks;
  final String? errorMessage;
  final Object? error;
  final bool isLoadingMore;
  final bool hasReachedMax;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.artists = const [],
    this.tracks = const [],
    this.selectedPlatforms = const {},
    this.totalArtists = 0,
    this.totalTracks = 0,
    this.errorMessage,
    this.error,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
  });

  bool get hasResults => artists.isNotEmpty || tracks.isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Artist>? artists,
    List<Track>? tracks,
    Set<String>? selectedPlatforms,
    int? totalArtists,
    int? totalTracks,
    String? errorMessage,
    Object? error,
    bool? isLoadingMore,
    bool? hasReachedMax,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      artists: artists ?? this.artists,
      tracks: tracks ?? this.tracks,
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
      totalArtists: totalArtists ?? this.totalArtists,
      totalTracks: totalTracks ?? this.totalTracks,
      errorMessage: errorMessage,
      error: error,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        artists,
        tracks,
        selectedPlatforms,
        totalArtists,
        totalTracks,
        errorMessage,
        isLoadingMore,
        hasReachedMax,
      ];
}
