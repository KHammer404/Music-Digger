"""Rabbit Hole Radio — cross-platform endless music discovery."""

import logging
import random
from collections import Counter

from app.services.aggregation_service import AggregationService
from app.services.playback_resolver import PlaybackResolverService
from app.services.recommendation_service import RecommendationService
from app.matching.name_normalizer import normalize_name

logger = logging.getLogger(__name__)


class RadioService:
    """Generates cross-platform radio recommendations."""

    def __init__(
        self,
        recommendation: RecommendationService,
        aggregation: AggregationService,
    ):
        self._recommendation = recommendation
        self._aggregation = aggregation
        self._playback = PlaybackResolverService()

    async def get_next_track(
        self,
        current_artist_name: str,
        played_artist_names: list[str],
        played_platforms: list[str],
    ) -> dict | None:
        """Get the next track for rabbit hole radio.

        Prioritizes:
        1. Similar artists not yet played
        2. Platforms not recently used (cross-platform diversity)
        3. Playable tracks only
        """
        # 1. Get similar artists
        similar = await self._recommendation.get_similar_artists(
            current_artist_name, limit=30,
        )
        if not similar:
            return None

        # 2. Filter out already-played artists
        played_normalized = {normalize_name(n) for n in played_artist_names}
        candidates = [
            a for a in similar
            if normalize_name(a.get("name", "")) not in played_normalized
        ]

        if not candidates:
            # All similar artists played; allow repeats but re-rank
            candidates = similar

        # 3. Score candidates by platform diversity
        platform_counts = Counter(played_platforms[-10:])  # recent 10 plays
        scored = []
        for artist in candidates:
            name = artist.get("name", "")
            platform = artist.get("platform", "")
            match_score = artist.get("match_score", 0.0)

            # Prefer platforms less recently used
            platform_penalty = platform_counts.get(platform, 0) * 0.15
            # Bonus for artists not yet played
            novelty_bonus = 0.3 if normalize_name(name) not in played_normalized else 0.0

            final_score = match_score + novelty_bonus - platform_penalty
            scored.append((final_score, artist))

        scored.sort(key=lambda x: x[0], reverse=True)

        # 4. Try top candidates until we find a playable track
        for _, candidate in scored[:10]:
            track = await self._find_playable_track(
                candidate.get("name", ""),
                candidate.get("platform"),
                candidate.get("platform_id"),
            )
            if track:
                source = track["source_track"]
                playback_info = self._playback.resolve(source)

                return {
                    "track": {
                        "title": source.title,
                        "artist": source.artist_name,
                        "platform": source.platform,
                        "platform_track_id": source.platform_id,
                        "url": source.url,
                        "thumbnail_url": source.thumbnail_url,
                        "duration_seconds": source.duration_seconds,
                    },
                    "playback": {
                        "engine": playback_info.engine,
                        "stream_url": playback_info.stream_url,
                    },
                    "reason": f"Similar to {current_artist_name}",
                }

        return None

    async def _find_playable_track(
        self,
        artist_name: str,
        platform: str | None = None,
        platform_id: str | None = None,
    ) -> dict | None:
        """Find a playable track for the given artist."""
        playable_platforms = {"youtube", "spotify", "soundcloud", "bandcamp", "niconico"}

        # Try getting tracks from the specific platform first
        if platform and platform_id and platform in playable_platforms:
            try:
                tracks = await self._aggregation.get_artist_tracks(platform, platform_id, limit=10)
                playable = [t for t in tracks if t.is_playable and t.platform in playable_platforms]
                if playable:
                    chosen = random.choice(playable[:5])  # pick from top 5
                    return {"source_track": chosen}
            except Exception:
                pass

        # Fallback: search across all platforms
        try:
            tracks = await self._aggregation.search_tracks(artist_name, limit=10)
            playable = [t for t in tracks if t.is_playable and t.platform in playable_platforms]
            if playable:
                chosen = random.choice(playable[:5])
                return {"source_track": chosen}
        except Exception:
            pass

        return None
