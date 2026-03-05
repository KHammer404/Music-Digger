import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiClient _apiClient;

  HomeBloc(this._apiClient) : super(const HomeState()) {
    on<HomeLoadRequested>(_onLoad);
    on<HomeSimilarArtistsRequested>(_onSimilarArtists);
  }

  Future<void> _onLoad(HomeLoadRequested event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      // Get discovery/trending artists
      final resp = await _apiClient.get('/recommendations/discover', queryParameters: {
        'limit': 100,
      });
      final data = resp.data as Map<String, dynamic>;
      final discoveries = (data['discoveries'] as List)
          .map((d) => RecommendedArtist.fromJson(d as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(
        status: HomeStatus.loaded,
        discoveries: discoveries,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: e.toString(),
        error: e,
      ));
    }
  }

  Future<void> _onSimilarArtists(
    HomeSimilarArtistsRequested event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final resp = await _apiClient.get('/recommendations/similar-artists', queryParameters: {
        'artist_name': event.artistName,
        if (event.platform != null) 'platform': event.platform,
        if (event.platformId != null) 'platform_id': event.platformId,
        'limit': 20,
      });
      final data = resp.data as Map<String, dynamic>;
      final similar = (data['similar_artists'] as List)
          .map((a) => RecommendedArtist.fromJson(a as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(
        similarArtists: similar,
        similarArtistsFor: event.artistName,
      ));
    } catch (_) {}
  }
}
