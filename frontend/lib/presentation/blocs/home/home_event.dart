import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Load the home screen: trending + personalized recommendations.
class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

/// Load similar artists for a specific artist.
class HomeSimilarArtistsRequested extends HomeEvent {
  final String artistName;
  final String? platform;
  final String? platformId;

  const HomeSimilarArtistsRequested(
    this.artistName, {
    this.platform,
    this.platformId,
  });

  @override
  List<Object?> get props => [artistName, platform, platformId];
}
