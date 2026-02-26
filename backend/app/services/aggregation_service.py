"""Aggregation service — searches across all available sources in parallel."""

import asyncio

from app.matching.alias_resolver import AliasResolver
from app.matching.track_fingerprint import TrackFingerprint
from app.services.dedup_service import DeduplicationService
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack


class AggregationService:
    """Aggregates search results from multiple platform adapters."""

    def __init__(self, adapters: list[SourceAdapter], vocadb_adapter=None):
        self._adapters = adapters
        self._alias_resolver = AliasResolver(vocadb_adapter)
        self._dedup = DeduplicationService()

    def _get_active_adapters(self, platforms: list[str] | None = None) -> list[SourceAdapter]:
        if not platforms:
            return self._adapters
        return [a for a in self._adapters if a.platform_name in platforms]

    async def search_artists(
        self,
        query: str,
        limit: int = 10,
        platforms: list[str] | None = None,
    ) -> list[SourceArtist]:
        """Search for artists across all platforms in parallel."""
        adapters = self._get_active_adapters(platforms)
        tasks = [adapter.search_artists(query, limit=limit) for adapter in adapters]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_artists = []
        for result in results:
            if isinstance(result, list):
                all_artists.extend(result)

        # Group same artists across platforms
        groups = self._alias_resolver.group_same_artists(all_artists)

        # Merge each group into a single artist with platform info
        merged = []
        for group in groups:
            merged.append(_merge_artist_group(group))

        return merged[:limit]

    async def search_tracks(
        self,
        query: str,
        limit: int = 20,
        platforms: list[str] | None = None,
    ) -> list[SourceTrack]:
        """Search for tracks across all platforms in parallel."""
        adapters = self._get_active_adapters(platforms)
        tasks = [adapter.search_tracks(query, limit=limit) for adapter in adapters]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_tracks = []
        for result in results:
            if isinstance(result, list):
                all_tracks.extend(result)

        return all_tracks

    async def search_tracks_deduped(
        self,
        query: str,
        limit: int = 20,
        platforms: list[str] | None = None,
    ) -> list[TrackFingerprint]:
        """Search tracks and deduplicate across platforms."""
        tracks = await self.search_tracks(query, limit=limit * 2, platforms=platforms)
        fingerprints = self._dedup.deduplicate(tracks)
        return fingerprints[:limit]

    async def get_artist_tracks(
        self,
        platform: str,
        platform_id: str,
        limit: int = 50,
    ) -> list[SourceTrack]:
        for adapter in self._adapters:
            if adapter.platform_name == platform:
                return await adapter.get_artist_tracks(platform_id, limit=limit)
        return []

    async def get_artist(
        self,
        platform: str,
        platform_id: str,
    ) -> SourceArtist | None:
        for adapter in self._adapters:
            if adapter.platform_name == platform:
                return await adapter.get_artist(platform_id)
        return None


def _merge_artist_group(group: list[SourceArtist]) -> SourceArtist:
    """Merge multiple SourceArtists from different platforms into one."""
    if len(group) == 1:
        return group[0]

    # Pick the best name (prefer the one with most info)
    best = max(group, key=lambda a: (
        len(a.aliases),
        1 if a.image_url else 0,
        1 if a.description else 0,
        a.follower_count or 0,
    ))

    # Collect all aliases
    all_aliases = set()
    for a in group:
        all_aliases.add(a.name)
        all_aliases.update(a.aliases)
    all_aliases.discard(best.name)

    return SourceArtist(
        platform=best.platform,
        platform_id=best.platform_id,
        name=best.name,
        url=best.url,
        image_url=best.image_url or next((a.image_url for a in group if a.image_url), None),
        aliases=list(all_aliases),
        description=best.description or next((a.description for a in group if a.description), None),
        follower_count=best.follower_count,
        extra={
            "platforms": {a.platform: a.platform_id for a in group},
        },
    )


def source_artist_to_response(artist: SourceArtist) -> dict:
    """Convert a SourceArtist to API response format."""
    platform_counts = artist.extra.get("platforms", {})
    return {
        "id": f"{artist.platform}:{artist.platform_id}",
        "name": artist.name,
        "image_url": artist.image_url,
        "description": artist.description,
        "aliases": artist.aliases,
        "platform_track_counts": {p: 0 for p in platform_counts} if platform_counts else {},
    }


def source_track_to_response(track: SourceTrack) -> dict:
    """Convert a SourceTrack to API response format."""
    return {
        "id": f"{track.platform}:{track.platform_id}",
        "title": track.title,
        "artist_name": track.artist_name,
        "artist_id": None,
        "duration_seconds": track.duration_seconds,
        "thumbnail_url": track.thumbnail_url,
        "release_date": track.release_date,
        "sources": [
            {
                "platform": track.platform,
                "platform_track_id": track.platform_id,
                "url": track.url,
                "thumbnail_url": track.thumbnail_url,
                "view_count": track.view_count,
                "like_count": track.like_count,
                "is_playable": track.is_playable,
            }
        ],
    }
