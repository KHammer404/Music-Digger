import 'package:equatable/equatable.dart';

enum LibraryStatus { initial, loading, loaded, error }

class PlaylistItem extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int trackCount;
  final String? imageUrl;

  const PlaylistItem({
    required this.id,
    required this.name,
    this.description,
    this.trackCount = 0,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, name, description, trackCount, imageUrl];
}

class FavoriteItem extends Equatable {
  final String id;
  final String targetType;
  final String targetId;
  final String createdAt;

  const FavoriteItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, targetType, targetId, createdAt];
}

class HistoryItem extends Equatable {
  final String id;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? query;
  final String? platform;
  final String createdAt;

  const HistoryItem({
    required this.id,
    required this.action,
    this.targetType,
    this.targetId,
    this.query,
    this.platform,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, action, targetType, createdAt];
}

class LibraryState extends Equatable {
  final LibraryStatus status;
  final List<PlaylistItem> playlists;
  final List<FavoriteItem> favorites;
  final List<HistoryItem> history;
  final String? errorMessage;
  final bool isLoadingMoreFavorites;
  final bool hasReachedMaxFavorites;
  final bool isLoadingMoreHistory;
  final bool hasReachedMaxHistory;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.playlists = const [],
    this.favorites = const [],
    this.history = const [],
    this.errorMessage,
    this.isLoadingMoreFavorites = false,
    this.hasReachedMaxFavorites = false,
    this.isLoadingMoreHistory = false,
    this.hasReachedMaxHistory = false,
  });

  LibraryState copyWith({
    LibraryStatus? status,
    List<PlaylistItem>? playlists,
    List<FavoriteItem>? favorites,
    List<HistoryItem>? history,
    String? errorMessage,
    bool? isLoadingMoreFavorites,
    bool? hasReachedMaxFavorites,
    bool? isLoadingMoreHistory,
    bool? hasReachedMaxHistory,
  }) {
    return LibraryState(
      status: status ?? this.status,
      playlists: playlists ?? this.playlists,
      favorites: favorites ?? this.favorites,
      history: history ?? this.history,
      errorMessage: errorMessage,
      isLoadingMoreFavorites: isLoadingMoreFavorites ?? this.isLoadingMoreFavorites,
      hasReachedMaxFavorites: hasReachedMaxFavorites ?? this.hasReachedMaxFavorites,
      isLoadingMoreHistory: isLoadingMoreHistory ?? this.isLoadingMoreHistory,
      hasReachedMaxHistory: hasReachedMaxHistory ?? this.hasReachedMaxHistory,
    );
  }

  @override
  List<Object?> get props => [
        status, playlists, favorites, history, errorMessage,
        isLoadingMoreFavorites, hasReachedMaxFavorites,
        isLoadingMoreHistory, hasReachedMaxHistory,
      ];
}
