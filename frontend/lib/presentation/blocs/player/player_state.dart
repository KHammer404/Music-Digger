import 'package:equatable/equatable.dart';

import '../../../domain/entities/track.dart';

class PlayerState extends Equatable {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final List<Track> queue;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.queue = const [],
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
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [currentTrack, isPlaying, position, duration, queue];
}
