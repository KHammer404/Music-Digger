"""Track fingerprinting for deduplication across platforms."""

from dataclasses import dataclass

from app.matching.fuzzy_matcher import is_same_track, track_title_similarity
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceTrack


@dataclass
class TrackFingerprint:
    """A fingerprint representing a unique track across platforms."""
    normalized_title: str
    normalized_artist: str
    duration_seconds: int | None
    isrc: str | None
    sources: list[SourceTrack]

    @property
    def best_source(self) -> SourceTrack | None:
        """Get the best source for playback based on priority."""
        priority = {"spotify": 1, "youtube": 2, "soundcloud": 3, "niconico": 4, "bandcamp": 5}
        playable = [s for s in self.sources if s.is_playable]
        if not playable:
            return self.sources[0] if self.sources else None
        return min(playable, key=lambda s: priority.get(s.platform, 99))

    @property
    def total_views(self) -> int:
        return sum(s.view_count or 0 for s in self.sources)


def deduplicate_tracks(tracks: list[SourceTrack]) -> list[TrackFingerprint]:
    """Group duplicate tracks from different platforms into fingerprints.

    Strategy:
    1. ISRC exact match (most reliable)
    2. Title similarity + duration proximity + artist overlap
    """
    fingerprints: list[TrackFingerprint] = []

    for track in tracks:
        matched = False

        # Try ISRC match first
        if track.isrc:
            for fp in fingerprints:
                if fp.isrc and fp.isrc == track.isrc:
                    fp.sources.append(track)
                    matched = True
                    break

        if not matched:
            # Try fuzzy match
            for fp in fingerprints:
                if is_same_track(
                    title_a=track.title,
                    title_b=fp.sources[0].title,
                    duration_a=track.duration_seconds,
                    duration_b=fp.duration_seconds,
                    artist_a=track.artist_name,
                    artist_b=fp.sources[0].artist_name,
                ):
                    fp.sources.append(track)
                    matched = True
                    break

        if not matched:
            fingerprints.append(TrackFingerprint(
                normalized_title=normalize_name(track.title),
                normalized_artist=normalize_name(track.artist_name),
                duration_seconds=track.duration_seconds,
                isrc=track.isrc if hasattr(track, 'isrc') else None,
                sources=[track],
            ))

    return fingerprints
