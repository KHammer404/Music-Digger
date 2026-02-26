import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../domain/entities/track.dart';
import 'source_badge.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: track.thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: track.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, color: Colors.grey),
                ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          ...track.sources.take(3).map(
                (source) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: SourceBadge(platform: source.platform, size: 16),
                ),
              ),
        ],
      ),
      trailing: Text(
        track.durationFormatted,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
