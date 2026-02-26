import 'package:equatable/equatable.dart';

enum HomeStatus { initial, loading, loaded, error }

class RecommendedArtist extends Equatable {
  final String name;
  final String? imageUrl;
  final String platform;
  final String platformId;
  final String? url;
  final double matchScore;

  const RecommendedArtist({
    required this.name,
    this.imageUrl,
    required this.platform,
    required this.platformId,
    this.url,
    this.matchScore = 0.0,
  });

  factory RecommendedArtist.fromJson(Map<String, dynamic> json) {
    return RecommendedArtist(
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      platform: json['platform'] as String? ?? '',
      platformId: json['platform_id'] as String? ?? '',
      url: json['url'] as String?,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [name, platform, platformId];
}

class HomeState extends Equatable {
  final HomeStatus status;
  final List<RecommendedArtist> discoveries;
  final List<RecommendedArtist> similarArtists;
  final String? similarArtistsFor;
  final String? errorMessage;
  final Object? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.discoveries = const [],
    this.similarArtists = const [],
    this.similarArtistsFor,
    this.errorMessage,
    this.error,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<RecommendedArtist>? discoveries,
    List<RecommendedArtist>? similarArtists,
    String? similarArtistsFor,
    String? errorMessage,
    Object? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      discoveries: discoveries ?? this.discoveries,
      similarArtists: similarArtists ?? this.similarArtists,
      similarArtistsFor: similarArtistsFor ?? this.similarArtistsFor,
      errorMessage: errorMessage,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, discoveries, similarArtists, similarArtistsFor, errorMessage];
}
