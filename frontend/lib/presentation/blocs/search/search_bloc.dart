import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/search_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _searchRepository;

  SearchBloc(this._searchRepository) : super(const SearchState()) {
    on<SearchSubmitted>(_onSearchSubmitted);
    on<SearchPlatformToggled>(_onPlatformToggled);
    on<SearchCleared>(_onCleared);
    on<SearchLoadMore>(_onLoadMore);
  }

  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.trim().isEmpty) return;

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: event.query,
    ));

    try {
      final platforms = state.selectedPlatforms.isEmpty
          ? null
          : state.selectedPlatforms.toList();

      final result = await _searchRepository.search(
        query: event.query,
        platforms: platforms,
      );

      emit(state.copyWith(
        status: SearchStatus.loaded,
        artists: result.artists,
        tracks: result.tracks,
        totalArtists: result.totalArtists,
        totalTracks: result.totalTracks,
        hasReachedMax: result.tracks.length >= result.totalTracks,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e is Exception ? e.toString() : 'An error occurred',
        error: e,
      ));
    }
  }

  void _onPlatformToggled(
    SearchPlatformToggled event,
    Emitter<SearchState> emit,
  ) {
    final platforms = Set<String>.from(state.selectedPlatforms);
    if (platforms.contains(event.platform)) {
      platforms.remove(event.platform);
    } else {
      platforms.add(event.platform);
    }
    emit(state.copyWith(selectedPlatforms: platforms));

    // Re-search if there's an active query
    if (state.query.isNotEmpty) {
      add(SearchSubmitted(state.query));
    }
  }

  void _onCleared(SearchCleared event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }

  Future<void> _onLoadMore(
    SearchLoadMore event,
    Emitter<SearchState> emit,
  ) async {
    if (state.status != SearchStatus.loaded) return;
    if (state.isLoadingMore || state.hasReachedMax) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final platforms = state.selectedPlatforms.isEmpty
          ? null
          : state.selectedPlatforms.toList();

      final result = await _searchRepository.search(
        query: state.query,
        platforms: platforms,
        offset: state.tracks.length,
      );

      final allTracks = [...state.tracks, ...result.tracks];
      emit(state.copyWith(
        tracks: allTracks,
        totalTracks: result.totalTracks,
        isLoadingMore: false,
        hasReachedMax: allTracks.length >= result.totalTracks || result.tracks.isEmpty,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
