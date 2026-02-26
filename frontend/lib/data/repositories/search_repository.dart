import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../datasources/remote_datasource.dart';

class SearchRepository {
  final RemoteDataSource _remoteDataSource;

  SearchRepository(this._remoteDataSource);

  Future<({List<Artist> artists, List<Track> tracks, int totalArtists, int totalTracks})> search({
    required String query,
    List<String>? platforms,
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await _remoteDataSource.search(
      query: query,
      platforms: platforms,
      limit: limit,
      offset: offset,
    );

    return (
      artists: result.artists.map((a) => a.toEntity()).toList(),
      tracks: result.tracks.map((t) => t.toEntity()).toList(),
      totalArtists: result.totalArtists,
      totalTracks: result.totalTracks,
    );
  }

  Future<({Artist artist, List<Track> tracks, int totalTracks})> getArtist({
    required String artistId,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _remoteDataSource.getArtist(
      artistId: artistId,
      limit: limit,
      offset: offset,
    );

    return (
      artist: result.artist.toEntity(),
      tracks: result.tracks.map((t) => t.toEntity()).toList(),
      totalTracks: result.totalTracks,
    );
  }
}
