import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import 'library_event.dart';
import 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final ApiClient _apiClient;
  final String _userId;

  static const _pageSize = 50;

  LibraryBloc(this._apiClient, this._userId) : super(const LibraryState()) {
    on<LibraryLoadPlaylists>(_onLoadPlaylists);
    on<LibraryLoadFavorites>(_onLoadFavorites);
    on<LibraryLoadMoreFavorites>(_onLoadMoreFavorites);
    on<LibraryLoadHistory>(_onLoadHistory);
    on<LibraryLoadMoreHistory>(_onLoadMoreHistory);
    on<LibraryCreatePlaylist>(_onCreatePlaylist);
    on<LibraryDeletePlaylist>(_onDeletePlaylist);
  }

  Future<void> _onLoadPlaylists(LibraryLoadPlaylists event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(status: LibraryStatus.loading));
    try {
      final resp = await _apiClient.get('/playlists', queryParameters: {'user_id': _userId});
      final data = resp.data as List;
      final playlists = data.map((p) => PlaylistItem(
        id: p['id'] as String,
        name: p['name'] as String,
        description: p['description'] as String?,
        trackCount: p['track_count'] as int? ?? 0,
        imageUrl: p['image_url'] as String?,
      )).toList();
      emit(state.copyWith(status: LibraryStatus.loaded, playlists: playlists));
    } catch (e) {
      emit(state.copyWith(status: LibraryStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadFavorites(LibraryLoadFavorites event, Emitter<LibraryState> emit) async {
    try {
      final resp = await _apiClient.get('/favorites', queryParameters: {
        'user_id': _userId,
        'limit': _pageSize,
        'offset': 0,
      });
      final data = resp.data as List;
      final favorites = _parseFavorites(data);
      emit(state.copyWith(
        favorites: favorites,
        hasReachedMaxFavorites: favorites.length < _pageSize,
      ));
    } catch (_) {}
  }

  Future<void> _onLoadMoreFavorites(LibraryLoadMoreFavorites event, Emitter<LibraryState> emit) async {
    if (state.isLoadingMoreFavorites || state.hasReachedMaxFavorites) return;

    emit(state.copyWith(isLoadingMoreFavorites: true));
    try {
      final resp = await _apiClient.get('/favorites', queryParameters: {
        'user_id': _userId,
        'limit': _pageSize,
        'offset': state.favorites.length,
      });
      final data = resp.data as List;
      final newFavorites = _parseFavorites(data);
      emit(state.copyWith(
        favorites: [...state.favorites, ...newFavorites],
        isLoadingMoreFavorites: false,
        hasReachedMaxFavorites: newFavorites.length < _pageSize,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMoreFavorites: false));
    }
  }

  Future<void> _onLoadHistory(LibraryLoadHistory event, Emitter<LibraryState> emit) async {
    try {
      final resp = await _apiClient.get('/history', queryParameters: {
        'user_id': _userId,
        'limit': _pageSize,
        'offset': 0,
      });
      final data = resp.data as List;
      final history = _parseHistory(data);
      emit(state.copyWith(
        history: history,
        hasReachedMaxHistory: history.length < _pageSize,
      ));
    } catch (_) {}
  }

  Future<void> _onLoadMoreHistory(LibraryLoadMoreHistory event, Emitter<LibraryState> emit) async {
    if (state.isLoadingMoreHistory || state.hasReachedMaxHistory) return;

    emit(state.copyWith(isLoadingMoreHistory: true));
    try {
      final resp = await _apiClient.get('/history', queryParameters: {
        'user_id': _userId,
        'limit': _pageSize,
        'offset': state.history.length,
      });
      final data = resp.data as List;
      final newHistory = _parseHistory(data);
      emit(state.copyWith(
        history: [...state.history, ...newHistory],
        isLoadingMoreHistory: false,
        hasReachedMaxHistory: newHistory.length < _pageSize,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMoreHistory: false));
    }
  }

  Future<void> _onCreatePlaylist(LibraryCreatePlaylist event, Emitter<LibraryState> emit) async {
    try {
      await _apiClient.post('/playlists', data: {
        'user_id': _userId,
        'name': event.name,
        'description': event.description,
      });
      add(const LibraryLoadPlaylists());
    } catch (_) {}
  }

  Future<void> _onDeletePlaylist(LibraryDeletePlaylist event, Emitter<LibraryState> emit) async {
    try {
      await _apiClient.delete('/playlists/${event.playlistId}');
      add(const LibraryLoadPlaylists());
    } catch (_) {}
  }

  List<FavoriteItem> _parseFavorites(List data) {
    return data.map((f) => FavoriteItem(
      id: f['id'] as String,
      targetType: f['target_type'] as String,
      targetId: f['target_id'] as String,
      createdAt: f['created_at'] as String,
    )).toList();
  }

  List<HistoryItem> _parseHistory(List data) {
    return data.map((h) => HistoryItem(
      id: h['id'] as String,
      action: h['action'] as String,
      targetType: h['target_type'] as String?,
      targetId: h['target_id'] as String?,
      query: h['query'] as String?,
      platform: h['platform'] as String?,
      createdAt: h['created_at'] as String,
    )).toList();
  }
}
