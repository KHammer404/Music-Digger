import 'package:equatable/equatable.dart';

import '../../../domain/entities/track.dart';

sealed class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayerPlayTrack extends PlayerEvent {
  final Track track;
  const PlayerPlayTrack(this.track);

  @override
  List<Object?> get props => [track];
}

class PlayerPlayQueue extends PlayerEvent {
  final List<Track> tracks;
  final int startIndex;
  const PlayerPlayQueue(this.tracks, {this.startIndex = 0});

  @override
  List<Object?> get props => [tracks, startIndex];
}

class PlayerTogglePlayPause extends PlayerEvent {
  const PlayerTogglePlayPause();
}

class PlayerNext extends PlayerEvent {
  const PlayerNext();
}

class PlayerPrevious extends PlayerEvent {
  const PlayerPrevious();
}

class PlayerSeek extends PlayerEvent {
  final Duration position;
  const PlayerSeek(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerStop extends PlayerEvent {
  const PlayerStop();
}

// Rabbit hole radio
class PlayerToggleRabbitHole extends PlayerEvent {
  const PlayerToggleRabbitHole();
}

class PlayerRabbitHoleNext extends PlayerEvent {
  const PlayerRabbitHoleNext();
}

// Internal events driven by stream subscriptions
class PlayerTrackChanged extends PlayerEvent {
  final Track? track;
  const PlayerTrackChanged(this.track);

  @override
  List<Object?> get props => [track];
}

class PlayerPlayingChanged extends PlayerEvent {
  final bool isPlaying;
  const PlayerPlayingChanged(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

class PlayerPositionChanged extends PlayerEvent {
  final Duration position;
  const PlayerPositionChanged(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerDurationChanged extends PlayerEvent {
  final Duration? duration;
  const PlayerDurationChanged(this.duration);

  @override
  List<Object?> get props => [duration];
}
