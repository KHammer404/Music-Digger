import 'package:equatable/equatable.dart';

sealed class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

class LibraryLoadPlaylists extends LibraryEvent {
  const LibraryLoadPlaylists();
}

class LibraryLoadFavorites extends LibraryEvent {
  const LibraryLoadFavorites();
}

class LibraryLoadMoreFavorites extends LibraryEvent {
  const LibraryLoadMoreFavorites();
}

class LibraryLoadHistory extends LibraryEvent {
  const LibraryLoadHistory();
}

class LibraryLoadMoreHistory extends LibraryEvent {
  const LibraryLoadMoreHistory();
}

class LibraryCreatePlaylist extends LibraryEvent {
  final String name;
  final String? description;
  const LibraryCreatePlaylist(this.name, {this.description});

  @override
  List<Object?> get props => [name, description];
}

class LibraryDeletePlaylist extends LibraryEvent {
  final String playlistId;
  const LibraryDeletePlaylist(this.playlistId);

  @override
  List<Object?> get props => [playlistId];
}
