import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/player/player_state.dart';
import '../widgets/source_badge.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final track = state.currentTrack;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Now Playing', style: TextStyle(fontSize: 14)),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(),

                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: track?.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track!.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _placeholder(),
                            errorWidget: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),

                const SizedBox(height: 32),

                // Track info
                Text(
                  track?.title ?? 'No track',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  track?.artistName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),

                // Source badges
                if (track != null && track.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: track.sources
                        .map((s) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Chip(
                                avatar:
                                    SourceBadge(platform: s.platform, size: 16),
                                label: Text(
                                  SourceBadge.displayName(s.platform),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const Spacer(),

                // Progress bar
                Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Colors.grey[700],
                      ),
                      child: Slider(
                        value: state.progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          if (state.duration != null) {
                            final position = Duration(
                              milliseconds:
                                  (value * state.duration!.inMilliseconds)
                                      .toInt(),
                            );
                            context
                                .read<PlayerBloc>()
                                .add(PlayerSeek(position));
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.positionFormatted,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                          Text(state.durationFormatted,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Rabbit hole reason
                if (state.rabbitHoleEnabled && state.rabbitHoleReason != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state.rabbitHoleReason!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ],

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shuffle),
                      iconSize: 28,
                      color: Colors.grey,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 40,
                      onPressed: () =>
                          context.read<PlayerBloc>().add(const PlayerPrevious()),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: state.rabbitHoleLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                state.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              iconSize: 48,
                              color: Colors.white,
                              onPressed: () => context
                                  .read<PlayerBloc>()
                                  .add(const PlayerTogglePlayPause()),
                            ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: 40,
                      onPressed: () =>
                          context.read<PlayerBloc>().add(const PlayerNext()),
                    ),
                    const SizedBox(width: 16),
                    // Rabbit hole toggle
                    IconButton(
                      icon: Icon(
                        state.rabbitHoleEnabled
                            ? Icons.explore
                            : Icons.explore_outlined,
                      ),
                      iconSize: 28,
                      color: state.rabbitHoleEnabled
                          ? const Color(0xFF6C5CE7)
                          : Colors.grey,
                      tooltip: 'Rabbit Hole Radio',
                      onPressed: () => context
                          .read<PlayerBloc>()
                          .add(const PlayerToggleRabbitHole()),
                    ),
                  ],
                ),

                // Rabbit hole indicator
                if (state.rabbitHoleEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Rabbit Hole ON',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF6C5CE7).withAlpha(180),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _placeholder() {
    return Container(
      color: const Color(0xFF16213E),
      child: const Icon(Icons.music_note, size: 80, color: Colors.grey),
    );
  }
}
