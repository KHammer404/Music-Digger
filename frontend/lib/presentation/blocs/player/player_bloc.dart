import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../domain/entities/track.dart';
import '../../../playback/playback_manager.dart';
import 'player_event.dart';
import 'player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final PlaybackManager _playbackManager;
  final ApiClient _apiClient;
  StreamSubscription? _trackSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  PlayerBloc(this._playbackManager, this._apiClient) : super(const PlayerState()) {
    on<PlayerPlayTrack>(_onPlayTrack);
    on<PlayerPlayQueue>(_onPlayQueue);
    on<PlayerTogglePlayPause>(_onTogglePlayPause);
    on<PlayerNext>(_onNext);
    on<PlayerPrevious>(_onPrevious);
    on<PlayerSeek>(_onSeek);
    on<PlayerStop>(_onStop);
    on<PlayerTrackChanged>(_onTrackChanged);
    on<PlayerPlayingChanged>(_onPlayingChanged);
    on<PlayerPositionChanged>(_onPositionChanged);
    on<PlayerDurationChanged>(_onDurationChanged);
    on<PlayerToggleRabbitHole>(_onToggleRabbitHole);
    on<PlayerRabbitHoleNext>(_onRabbitHoleNext);

    _trackSub = _playbackManager.trackStream.listen((track) {
      add(PlayerTrackChanged(track));
    });

    _playingSub = _playbackManager.playingStream.listen((playing) {
      add(PlayerPlayingChanged(playing));
    });

    _positionSub = _playbackManager.positionStream.listen((position) {
      add(PlayerPositionChanged(position));
    });

    _durationSub = _playbackManager.durationStream.listen((duration) {
      add(PlayerDurationChanged(duration));
    });

    _completedSub = _playbackManager.completedStream.listen((_) {
      // Track completed with no queue — trigger rabbit hole if enabled
      if (state.rabbitHoleEnabled) {
        add(const PlayerRabbitHoleNext());
      }
    });
  }

  Future<void> _onPlayTrack(PlayerPlayTrack event, Emitter<PlayerState> emit) async {
    // Track play history for rabbit hole
    final newArtists = [...state.playedArtistNames, event.track.artistName];
    final newPlatforms = [...state.playedPlatforms];
    final bestSource = event.track.bestSource;
    if (bestSource != null) {
      newPlatforms.add(bestSource.platform);
    }

    emit(state.copyWith(
      currentTrack: event.track,
      isPlaying: true,
      playedArtistNames: newArtists,
      playedPlatforms: newPlatforms,
      rabbitHoleReason: null,
    ));
    await _playbackManager.play(event.track);
  }

  Future<void> _onPlayQueue(PlayerPlayQueue event, Emitter<PlayerState> emit) async {
    emit(state.copyWith(queue: event.tracks));
    _playbackManager.setQueue(event.tracks, startIndex: event.startIndex);
  }

  Future<void> _onTogglePlayPause(PlayerTogglePlayPause event, Emitter<PlayerState> emit) async {
    await _playbackManager.togglePlayPause();
  }

  Future<void> _onNext(PlayerNext event, Emitter<PlayerState> emit) async {
    // If rabbit hole is enabled and queue is empty/exhausted, fetch next
    if (state.rabbitHoleEnabled && _playbackManager.queue.isEmpty) {
      add(const PlayerRabbitHoleNext());
      return;
    }
    await _playbackManager.next();
  }

  Future<void> _onPrevious(PlayerPrevious event, Emitter<PlayerState> emit) async {
    await _playbackManager.previous();
  }

  Future<void> _onSeek(PlayerSeek event, Emitter<PlayerState> emit) async {
    await _playbackManager.seekTo(event.position);
  }

  Future<void> _onStop(PlayerStop event, Emitter<PlayerState> emit) async {
    await _playbackManager.stop();
    emit(const PlayerState());
  }

  void _onTrackChanged(PlayerTrackChanged event, Emitter<PlayerState> emit) {
    emit(state.copyWith(currentTrack: event.track));
  }

  void _onPlayingChanged(PlayerPlayingChanged event, Emitter<PlayerState> emit) {
    emit(state.copyWith(isPlaying: event.isPlaying));
  }

  void _onPositionChanged(PlayerPositionChanged event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: event.position));
  }

  void _onDurationChanged(PlayerDurationChanged event, Emitter<PlayerState> emit) {
    emit(state.copyWith(duration: event.duration));
  }

  void _onToggleRabbitHole(PlayerToggleRabbitHole event, Emitter<PlayerState> emit) {
    emit(state.copyWith(
      rabbitHoleEnabled: !state.rabbitHoleEnabled,
      rabbitHoleReason: null,
    ));
  }

  Future<void> _onRabbitHoleNext(PlayerRabbitHoleNext event, Emitter<PlayerState> emit) async {
    if (!state.rabbitHoleEnabled) return;

    final currentArtist = state.currentTrack?.artistName;
    if (currentArtist == null) return;

    emit(state.copyWith(rabbitHoleLoading: true));

    try {
      final response = await _apiClient.post('/radio/next', data: {
        'current_artist_name': currentArtist,
        'played_artist_names': state.playedArtistNames,
        'played_platforms': state.playedPlatforms,
      });

      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error') || data['track'] == null) {
        emit(state.copyWith(rabbitHoleLoading: false));
        return;
      }

      final trackData = data['track'] as Map<String, dynamic>;
      final reason = data['reason'] as String?;

      // Build a Track entity from the radio response
      final track = Track(
        id: '${trackData['platform']}:${trackData['platform_track_id']}',
        title: trackData['title'] as String? ?? '',
        artistName: trackData['artist'] as String? ?? '',
        durationSeconds: trackData['duration_seconds'] as int?,
        thumbnailUrl: trackData['thumbnail_url'] as String?,
        sources: [
          TrackSource(
            platform: trackData['platform'] as String? ?? '',
            platformTrackId: trackData['platform_track_id'] as String? ?? '',
            url: trackData['url'] as String? ?? '',
            thumbnailUrl: trackData['thumbnail_url'] as String?,
            isPlayable: true,
          ),
        ],
      );

      emit(state.copyWith(
        rabbitHoleLoading: false,
        rabbitHoleReason: reason,
      ));

      // Play the track (which also updates history)
      add(PlayerPlayTrack(track));
    } catch (e) {
      dev.log('[RabbitHole] Failed to get next: $e', name: 'PlayerBloc');
      emit(state.copyWith(rabbitHoleLoading: false));
    }
  }

  @override
  Future<void> close() {
    _trackSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    return super.close();
  }
}
