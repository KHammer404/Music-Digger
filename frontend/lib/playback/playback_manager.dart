import 'dart:async';
import 'dart:developer' as dev;

import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../core/di/service_locator.dart';
import '../core/network/api_client.dart';
import '../domain/entities/track.dart';

enum PlaybackEngine { directAudio, youtube, webview, none }

class PlaybackManager {
  static final PlaybackManager _instance = PlaybackManager._();
  factory PlaybackManager() => _instance;
  PlaybackManager._() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  ApiClient get _apiClient => getIt<ApiClient>();

  Track? _currentTrack;
  final List<Track> _queue = [];
  int _queueIndex = -1;

  // Stream controllers for UI updates
  final _trackController = StreamController<Track?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _completedController = StreamController<void>.broadcast();

  Stream<Track?> get trackStream => _trackController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<void> get completedStream => _completedController.stream;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _audioPlayer.playing;
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  List<Track> get queue => List.unmodifiable(_queue);

  void _init() {
    _audioPlayer.playerStateStream.listen((state) {
      _playingController.add(state.playing);
      if (state.processingState == ProcessingState.completed) {
        if (_queue.isNotEmpty) {
          next();
        } else {
          // No queue — signal completion for rabbit hole
          _completedController.add(null);
        }
      }
    });
  }

  Future<void> play(Track track) async {
    _currentTrack = track;
    _trackController.add(track);

    final source = track.bestSource;
    if (source == null) return;

    final engine = _resolveEngine(source.platform);

    switch (engine) {
      case PlaybackEngine.youtube:
        await _playYouTube(source.platformTrackId);
      case PlaybackEngine.directAudio:
        await _playWithStreamResolve(source);
      case PlaybackEngine.webview:
      case PlaybackEngine.none:
        // WebView and non-playable handled at UI level
        break;
    }
  }

  /// For SoundCloud/Bandcamp, resolve the actual stream URL via backend.
  /// Falls back to direct URL for other platforms.
  Future<void> _playWithStreamResolve(TrackSource source) async {
    final needsResolve = source.platform == 'soundcloud' ||
        source.platform == 'bandcamp';

    if (!needsResolve) {
      await _playDirect(source.url);
      return;
    }

    try {
      final response = await _apiClient.get(
        '/playback/${source.platform}/${source.platformTrackId}',
      );

      final data = response.data as Map<String, dynamic>;
      final streamUrl = data['stream_url'] as String?;

      if (streamUrl != null && streamUrl.isNotEmpty) {
        dev.log(
          '[Playback] Resolved stream URL for ${source.platform}/${source.platformTrackId}',
          name: 'PlaybackManager',
        );
        await _playDirect(streamUrl);
      } else {
        dev.log(
          '[Playback] No stream URL resolved, falling back to page URL',
          name: 'PlaybackManager',
        );
        await _playDirect(source.url);
      }
    } catch (e) {
      dev.log(
        '[Playback] Stream resolve failed: $e, falling back to page URL',
        name: 'PlaybackManager',
      );
      await _playDirect(source.url);
    }
  }

  Future<void> _playYouTube(String videoId) async {
    try {
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      await _audioPlayer.setUrl(audioStream.url.toString());
      await _audioPlayer.play();
    } catch (e) {
      // Fallback: try as direct URL
      await _playDirect('https://www.youtube.com/watch?v=$videoId');
    }
  }

  Future<void> _playDirect(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (_) {}
  }

  PlaybackEngine _resolveEngine(String platform) {
    return switch (platform) {
      'youtube' => PlaybackEngine.youtube,
      'spotify' || 'soundcloud' || 'bandcamp' => PlaybackEngine.directAudio,
      'niconico' => PlaybackEngine.webview,
      _ => PlaybackEngine.none,
    };
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    _trackController.add(null);
  }

  // Queue management
  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    _queue.clear();
    _queue.addAll(tracks);
    _queueIndex = startIndex;
    if (_queue.isNotEmpty && startIndex < _queue.length) {
      play(_queue[startIndex]);
    }
  }

  void addToQueue(Track track) {
    _queue.add(track);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _queueIndex = (_queueIndex + 1) % _queue.length;
    await play(_queue[_queueIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // If we're past 3 seconds, restart. Otherwise go to previous.
    if (_audioPlayer.position.inSeconds > 3) {
      await seekTo(Duration.zero);
    } else {
      _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
      await play(_queue[_queueIndex]);
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _youtubeExplode.close();
    _trackController.close();
    _playingController.close();
    _positionController.close();
    _durationController.close();
    _completedController.close();
  }
}
