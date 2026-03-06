import 'package:equatable/equatable.dart';

import '../../../domain/entities/track.dart';

class PlayerState extends Equatable {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final List<Track> queue;
  // Rabbit hole radio
  final bool rabbitHoleEnabled;
  final bool rabbitHoleLoading;
  final String? rabbitHoleReason;
  final List<String> playedArtistNames;
  final List<String> playedPlatforms;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.queue = const [],
    this.rabbitHoleEnabled = false,
    this.rabbitHoleLoading = false,
    this.rabbitHoleReason,
    this.playedArtistNames = const [],
    this.playedPlatforms = const [],
  });

  bool get hasTrack => currentTrack != null;

  String get positionFormatted => _formatDuration(position);
  String get durationFormatted => duration != null ? _formatDuration(duration!) : '--:--';

  double get progress {
    if (duration == null || duration!.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration!.inMilliseconds;
  }

  PlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<Track>? queue,
    bool? rabbitHoleEnabled,
    bool? rabbitHoleLoading,
    String? rabbitHoleReason,
    List<String>? playedArtistNames,
    List<String>? playedPlatforms,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      rabbitHoleEnabled: rabbitHoleEnabled ?? this.rabbitHoleEnabled,
      rabbitHoleLoading: rabbitHoleLoading ?? this.rabbitHoleLoading,
      rabbitHoleReason: rabbitHoleReason ?? this.rabbitHoleReason,
      playedArtistNames: playedArtistNames ?? this.playedArtistNames,
      playedPlatforms: playedPlatforms ?? this.playedPlatforms,
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        currentTrack, isPlaying, position, duration, queue,
        rabbitHoleEnabled, rabbitHoleLoading, rabbitHoleReason,
        playedArtistNames, playedPlatforms,
      ];
}
