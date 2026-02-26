import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../playback/playback_manager.dart';
import 'player_event.dart';
import 'player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final PlaybackManager _playbackManager;
  StreamSubscription? _trackSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  PlayerBloc(this._playbackManager) : super(const PlayerState()) {
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
  }

  Future<void> _onPlayTrack(PlayerPlayTrack event, Emitter<PlayerState> emit) async {
    emit(state.copyWith(currentTrack: event.track, isPlaying: true));
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

  @override
  Future<void> close() {
    _trackSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    return super.close();
  }
}
