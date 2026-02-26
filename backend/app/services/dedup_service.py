"""Deduplication service — merges duplicate tracks from multiple platforms."""

from app.matching.track_fingerprint import TrackFingerprint, deduplicate_tracks
from app.sources.base import SourceTrack


class DeduplicationService:
    """Deduplicates tracks that appear on multiple platforms."""

    def deduplicate(self, tracks: list[SourceTrack]) -> list[TrackFingerprint]:
        """Group duplicate tracks and return unique fingerprints.

        Sorted by total views (popularity) descending.
        """
        fingerprints = deduplicate_tracks(tracks)

        # Sort by number of sources (more platforms = more relevant) then by views
        fingerprints.sort(
            key=lambda fp: (len(fp.sources), fp.total_views),
            reverse=True,
        )

        return fingerprints

    def to_track_responses(self, fingerprints: list[TrackFingerprint]) -> list[dict]:
        """Convert fingerprints to API response format with all sources."""
        results = []
        for fp in fingerprints:
            best = fp.best_source
            if not best:
                continue

            results.append({
                "id": f"{best.platform}:{best.platform_id}",
                "title": best.title,
                "artist_name": best.artist_name,
                "artist_id": None,
                "duration_seconds": fp.duration_seconds,
                "thumbnail_url": best.thumbnail_url,
                "release_date": best.release_date if hasattr(best, 'release_date') else None,
                "sources": [
                    {
                        "platform": s.platform,
                        "platform_track_id": s.platform_id,
                        "url": s.url,
                        "thumbnail_url": s.thumbnail_url,
                        "view_count": s.view_count,
                        "like_count": s.like_count,
                        "is_playable": s.is_playable,
                    }
                    for s in fp.sources
                ],
            })

        return results
