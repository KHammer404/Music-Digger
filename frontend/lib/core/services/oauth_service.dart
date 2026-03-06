import 'dart:async';
import 'dart:developer' as dev;

import '../network/api_client.dart';

class OAuthConnection {
  final String platform;
  final bool connected;
  final String? displayName;
  final String? connectedAt;

  const OAuthConnection({
    required this.platform,
    required this.connected,
    this.displayName,
    this.connectedAt,
  });

  factory OAuthConnection.fromJson(Map<String, dynamic> json) {
    return OAuthConnection(
      platform: json['platform'] as String,
      connected: json['connected'] as bool? ?? false,
      displayName: json['display_name'] as String?,
      connectedAt: json['connected_at'] as String?,
    );
  }
}

class ExternalPlaylist {
  final String id;
  final String name;
  final String? description;
  final int trackCount;
  final String? imageUrl;
  final String? owner;

  const ExternalPlaylist({
    required this.id,
    required this.name,
    this.description,
    required this.trackCount,
    this.imageUrl,
    this.owner,
  });

  factory ExternalPlaylist.fromJson(Map<String, dynamic> json) {
    return ExternalPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      trackCount: json['track_count'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      owner: json['owner'] as String?,
    );
  }
}

class ExternalTrack {
  final String title;
  final String artist;
  final int? durationSeconds;
  final String? isrc;
  final String platform;
  final String platformTrackId;
  final String? url;
  final String? thumbnailUrl;

  const ExternalTrack({
    required this.title,
    required this.artist,
    this.durationSeconds,
    this.isrc,
    required this.platform,
    required this.platformTrackId,
    this.url,
    this.thumbnailUrl,
  });

  factory ExternalTrack.fromJson(Map<String, dynamic> json) {
    return ExternalTrack(
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      durationSeconds: json['duration_seconds'] as int?,
      isrc: json['isrc'] as String?,
      platform: json['platform'] as String? ?? '',
      platformTrackId: json['platform_track_id'] as String? ?? '',
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class OAuthService {
  final ApiClient _api;

  OAuthService(this._api);

  /// Get the OAuth authorization URL for a platform.
  Future<String> getConnectUrl(String platform, String userId) async {
    final resp = await _api.get(
      '/auth/$platform/connect',
      queryParameters: {'user_id': userId},
    );
    return resp.data['authorize_url'] as String;
  }

  /// Get all connections for a user.
  Future<List<OAuthConnection>> getConnections(String userId) async {
    final resp = await _api.get(
      '/auth/connections',
      queryParameters: {'user_id': userId},
    );
    final list = resp.data['connections'] as List;
    return list.map((c) => OAuthConnection.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Disconnect a platform.
  Future<void> disconnect(String platform, String userId) async {
    await _api.delete('/auth/$platform/disconnect?user_id=$userId');
  }

  /// List external playlists from a connected platform.
  Future<List<ExternalPlaylist>> getExternalPlaylists(String platform, String userId) async {
    final resp = await _api.get(
      '/external-playlists/$platform',
      queryParameters: {'user_id': userId},
    );
    final list = resp.data['playlists'] as List;
    return list.map((p) => ExternalPlaylist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Preview tracks from an external playlist.
  Future<List<ExternalTrack>> previewTracks(String platform, String playlistId, String userId) async {
    final resp = await _api.get(
      '/external-playlists/$platform/$playlistId/tracks',
      queryParameters: {'user_id': userId},
    );
    final list = resp.data['tracks'] as List;
    return list.map((t) => ExternalTrack.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Import an external playlist.
  Future<Map<String, dynamic>> importPlaylist(
    String platform,
    String playlistId,
    String userId, {
    String? playlistName,
  }) async {
    final params = <String, dynamic>{'user_id': userId};
    if (playlistName != null) params['playlist_name'] = playlistName;

    final resp = await _api.post(
      '/external-playlists/$platform/$playlistId/import?user_id=$userId${playlistName != null ? '&playlist_name=$playlistName' : ''}',
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Poll connections until a specific platform is connected.
  /// Returns a stream that emits connection lists.
  Stream<List<OAuthConnection>> pollConnections(String userId, {Duration interval = const Duration(seconds: 3)}) {
    late StreamController<List<OAuthConnection>> controller;
    Timer? timer;

    controller = StreamController<List<OAuthConnection>>(
      onListen: () {
        timer = Timer.periodic(interval, (_) async {
          try {
            final connections = await getConnections(userId);
            if (!controller.isClosed) {
              controller.add(connections);
            }
          } catch (e) {
            dev.log('[OAuthService] Poll error: $e', name: 'OAuthService');
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
