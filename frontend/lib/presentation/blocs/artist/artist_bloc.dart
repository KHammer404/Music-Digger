import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../data/repositories/search_repository.dart';
import '../home/home_state.dart';
import 'artist_event.dart';
import 'artist_state.dart';

class ArtistBloc extends Bloc<ArtistEvent, ArtistState> {
  final SearchRepository _searchRepository;
  final ApiClient _apiClient;
  String? _currentArtistId;

  ArtistBloc(this._searchRepository, this._apiClient) : super(const ArtistState()) {
    on<ArtistLoadRequested>(_onLoadRequested);
    on<ArtistLoadMoreTracks>(_onLoadMoreTracks);
    on<ArtistLoadSimilar>(_onLoadSimilar);
  }

  Future<void> _onLoadRequested(
    ArtistLoadRequested event,
    Emitter<ArtistState> emit,
  ) async {
    _currentArtistId = event.artistId;
    emit(const ArtistState(status: ArtistStatus.loading));

    try {
      final result = await _searchRepository.getArtist(
        artistId: event.artistId,
      );

      emit(ArtistState(
        status: ArtistStatus.loaded,
        artist: result.artist,
        tracks: result.tracks,
        totalTracks: result.totalTracks,
      ));

      // Auto-load similar artists
      final parts = event.artistId.split(':');
      add(ArtistLoadSimilar(
        result.artist.name,
        platform: parts.isNotEmpty ? parts[0] : null,
        platformId: parts.length > 1 ? parts.sublist(1).join(':') : null,
      ));
    } catch (e) {
      emit(ArtistState(
        status: ArtistStatus.error,
        errorMessage: e.toString(),
        error: e,
      ));
    }
  }

  Future<void> _onLoadMoreTracks(
    ArtistLoadMoreTracks event,
    Emitter<ArtistState> emit,
  ) async {
    if (_currentArtistId == null) return;
    if (state.isLoadingMore || state.hasReachedMax) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await _searchRepository.getArtist(
        artistId: _currentArtistId!,
        limit: 50,
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

  Future<void> _onLoadSimilar(
    ArtistLoadSimilar event,
    Emitter<ArtistState> emit,
  ) async {
    try {
      final resp = await _apiClient.get('/recommendations/similar-artists', queryParameters: {
        'artist_name': event.artistName,
        if (event.platform != null) 'platform': event.platform,
        if (event.platformId != null) 'platform_id': event.platformId,
        'limit': 15,
      });
      final data = resp.data as Map<String, dynamic>;
      final similar = (data['similar_artists'] as List)
          .map((a) => RecommendedArtist.fromJson(a as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(similarArtists: similar));
    } catch (_) {}
  }
}
