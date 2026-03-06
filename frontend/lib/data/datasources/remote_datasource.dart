import '../../core/network/api_client.dart';
import '../models/artist_model.dart';
import '../models/track_model.dart';

class SearchResult {
  final List<ArtistModel> artists;
  final List<TrackModel> tracks;
  final int totalArtists;
  final int totalTracks;

  SearchResult({
    required this.artists,
    required this.tracks,
    required this.totalArtists,
    required this.totalTracks,
  });
}

class ArtistDetail {
  final ArtistModel artist;
  final List<TrackModel> tracks;
  final int totalTracks;

  ArtistDetail({
    required this.artist,
    required this.tracks,
    required this.totalTracks,
  });
}

class RemoteDataSource {
  final ApiClient _apiClient;

  RemoteDataSource(this._apiClient);

  Future<SearchResult> search({
    required String query,
    List<String>? platforms,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get('/search', queryParameters: {
      'q': query,
      if (platforms != null && platforms.isNotEmpty)
        'platforms': platforms.join(','),
      'limit': limit,
      'offset': offset,
    });

    final data = response.data as Map<String, dynamic>;
    return SearchResult(
      artists: (data['artists'] as List)
          .map((a) => ArtistModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      tracks: (data['tracks'] as List)
          .map((t) => TrackModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      totalArtists: data['total_artists'] as int,
      totalTracks: data['total_tracks'] as int,
    );
  }

  Future<ArtistDetail> getArtist({
    required String artistId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      '/artists/$artistId',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final data = response.data as Map<String, dynamic>;
    return ArtistDetail(
      artist: ArtistModel.fromJson(data['artist'] as Map<String, dynamic>),
      tracks: (data['tracks'] as List)
          .map((t) => TrackModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      totalTracks: data['total_tracks'] as int,
    );
  }

  Future<List<Map<String, dynamic>>> getSimilarArtists({
    required String artistName,
    String? platform,
    String? platformId,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/recommendations/similar-artists',
      queryParameters: {
        'artist_name': artistName,
        if (platform != null) 'platform': platform,
        if (platformId != null) 'platform_id': platformId,
        'limit': limit,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return (data['similar_artists'] as List)
        .map((a) => a as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> crosslink({required String url}) async {
    final response = await _apiClient.post('/crosslink', data: {'url': url});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUnifiedArtist({
    required String platform,
    required String platformId,
    int trackLimit = 50,
  }) async {
    final response = await _apiClient.get(
      '/artists/unified/$platform:$platformId',
      queryParameters: {'track_limit': trackLimit},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRadioNext({
    required String currentArtistName,
    List<String> playedArtistNames = const [],
    List<String> playedPlatforms = const [],
  }) async {
    final response = await _apiClient.post('/radio/next', data: {
      'current_artist_name': currentArtistName,
      'played_artist_names': playedArtistNames,
      'played_platforms': playedPlatforms,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDiscovery({
    List<String>? seeds,
    int limit = 30,
  }) async {
    final response = await _apiClient.get(
      '/recommendations/discover',
      queryParameters: {
        if (seeds != null && seeds.isNotEmpty) 'seeds': seeds.join(','),
        'limit': limit,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return (data['discoveries'] as List)
        .map((d) => d as Map<String, dynamic>)
        .toList();
  }
}
