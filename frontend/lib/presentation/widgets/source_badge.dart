import 'package:flutter/material.dart';

class SourceBadge extends StatelessWidget {
  final String platform;
  final double size;

  const SourceBadge({
    super.key,
    required this.platform,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _platformColor.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          _platformInitial,
          style: TextStyle(
            color: _platformColor,
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String get _platformInitial {
    return switch (platform) {
      'youtube' => 'Y',
      'spotify' => 'S',
      'niconico' => 'N',
      'soundcloud' => 'C',
      'bandcamp' => 'B',
      'vocadb' => 'V',
      'musicbrainz' => 'M',
      'lastfm' => 'L',
      _ => '?',
    };
  }

  Color get _platformColor {
    return switch (platform) {
      'youtube' => const Color(0xFFFF0000),
      'spotify' => const Color(0xFF1DB954),
      'niconico' => const Color(0xFF252525),
      'soundcloud' => const Color(0xFFFF5500),
      'bandcamp' => const Color(0xFF1DA0C3),
      'vocadb' => const Color(0xFF3399FF),
      'musicbrainz' => const Color(0xFFBA478F),
      'lastfm' => const Color(0xFFD51007),
      _ => Colors.grey,
    };
  }

  static String displayName(String platform) {
    return switch (platform) {
      'youtube' => 'YouTube',
      'spotify' => 'Spotify',
      'niconico' => 'NicoNico',
      'soundcloud' => 'SoundCloud',
      'bandcamp' => 'Bandcamp',
      'vocadb' => 'VocaDB',
      'musicbrainz' => 'MusicBrainz',
      'lastfm' => 'Last.fm',
      _ => platform,
    };
  }
}
