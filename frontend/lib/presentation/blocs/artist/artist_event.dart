import 'package:equatable/equatable.dart';

sealed class ArtistEvent extends Equatable {
  const ArtistEvent();

  @override
  List<Object?> get props => [];
}

class ArtistLoadRequested extends ArtistEvent {
  final String artistId;
  const ArtistLoadRequested(this.artistId);

  @override
  List<Object?> get props => [artistId];
}

class ArtistLoadMoreTracks extends ArtistEvent {
  const ArtistLoadMoreTracks();
}

class ArtistLoadSimilar extends ArtistEvent {
  final String artistName;
  final String? platform;
  final String? platformId;

  const ArtistLoadSimilar(this.artistName, {this.platform, this.platformId});

  @override
  List<Object?> get props => [artistName, platform, platformId];
}
