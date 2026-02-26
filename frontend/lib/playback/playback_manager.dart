import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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

  Track? _currentTrack;
  final List<Track> _queue = [];
  int _queueIndex = -1;

  // Stream controllers for UI updates
  final _trackController = StreamController<Track?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  Stream<Track?> get trackStream => _trackController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _audioPlayer.playing;
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  List<Track> get queue => List.unmodifiable(_queue);

  void _init() {
    _audioPlayer.playerStateStream.listen((state) {
      _playingController.add(state.playing);
      if (state.processingState == ProcessingState.completed) {
        next();
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
        await _playDirect(source.url);
      case PlaybackEngine.webview:
      case PlaybackEngine.none:
        // WebView and non-playable handled at UI level
        break;
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
  }
}
