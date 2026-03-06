"""Crosslink service — finds the same track/artist across all 8 platforms."""

import logging
import re
from urllib.parse import urlparse, parse_qs

from app.cache.redis_cache import cache_get, cache_set
from app.services.aggregation_service import AggregationService
from app.services.playback_resolver import PlaybackResolverService
from app.sources.base import SourceTrack

logger = logging.getLogger(__name__)

CROSSLINK_CACHE_TTL = 3600  # 1 hour

# URL patterns: (compiled regex, platform, type, id_extractor)
_URL_PATTERNS = [
    # YouTube
    (re.compile(r'(?:youtube\.com/watch\?.*v=|youtu\.be/)([\w-]{11})'), 'youtube', 'track'),
    (re.compile(r'youtube\.com/channel/([\w-]+)'), 'youtube', 'artist'),
    (re.compile(r'youtube\.com/@([\w.-]+)'), 'youtube', 'artist'),
    # Spotify
    (re.compile(r'open\.spotify\.com/track/([\w]+)'), 'spotify', 'track'),
    (re.compile(r'open\.spotify\.com/artist/([\w]+)'), 'spotify', 'artist'),
    # NicoNico
    (re.compile(r'nicovideo\.jp/watch/(sm\d+)'), 'niconico', 'track'),
    # SoundCloud
    (re.compile(r'soundcloud\.com/([\w-]+)/([\w-]+)(?:\?|$)'), 'soundcloud', 'track'),
    (re.compile(r'soundcloud\.com/([\w-]+)(?:\?|$)'), 'soundcloud', 'artist'),
    # Bandcamp
    (re.compile(r'([\w-]+)\.bandcamp\.com/track/([\w-]+)'), 'bandcamp', 'track'),
    (re.compile(r'([\w-]+)\.bandcamp\.com(?:/|$)'), 'bandcamp', 'artist'),
]


def parse_music_url(url: str) -> dict | None:
    """Parse a music URL into platform, type, and platform_id.

    Returns dict with keys: platform, type ('track' or 'artist'), platform_id, url
    or None if the URL is not recognized.
    """
    url = url.strip()

    for pattern, platform, link_type in _URL_PATTERNS:
        m = pattern.search(url)
        if not m:
            continue

        groups = m.groups()

        # SoundCloud track: user/track → "user/track"
        if platform == 'soundcloud' and link_type == 'track':
            platform_id = f"{groups[0]}/{groups[1]}"
        # Bandcamp track: artist.bandcamp.com/track/slug
        elif platform == 'bandcamp' and link_type == 'track':
            platform_id = f"{groups[0]}/{groups[1]}"
        # Bandcamp artist
        elif platform == 'bandcamp' and link_type == 'artist':
            platform_id = groups[0]
        else:
            platform_id = groups[0]

        return {
            'platform': platform,
            'type': link_type,
            'platform_id': platform_id,
            'url': url,
        }

    return None


class CrosslinkService:
    """Finds the same track or artist across all platforms."""

    def __init__(self, aggregation: AggregationService):
        self._aggregation = aggregation
        self._playback = PlaybackResolverService()

    async def crosslink(self, url: str) -> dict:
        """Given a URL, find the same content on all other platforms."""
        cache_key = f"crosslink:{url}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached

        parsed = parse_music_url(url)
        if not parsed:
            return {"error": "Unrecognized URL format", "url": url}

        if parsed['type'] == 'track':
            result = await self._crosslink_track(parsed)
        else:
            result = await self._crosslink_artist(parsed)

        await cache_set(cache_key, result, CROSSLINK_CACHE_TTL)
        return result

    async def _crosslink_track(self, parsed: dict) -> dict:
        """Find the same track across all platforms."""
        platform = parsed['platform']
        platform_id = parsed['platform_id']

        # 1. Get original track metadata from the source platform
        original_tracks = await self._aggregation.get_artist_tracks(platform, platform_id, limit=1)
        original_meta = None

        if not original_tracks:
            # Try searching on the specific platform for the track
            adapter = self._get_adapter(platform)
            if adapter:
                try:
                    tracks = await adapter.search_tracks(platform_id, limit=1)
                    if tracks:
                        original_meta = tracks[0]
                except Exception:
                    pass

        if original_tracks:
            original_meta = original_tracks[0]

        # If we still don't have metadata, try the get_track pattern
        if original_meta is None:
            adapter = self._get_adapter(platform)
            if adapter and hasattr(adapter, 'get_track'):
                try:
                    original_meta = await adapter.get_track(platform_id)
                except Exception:
                    pass

        if original_meta is None:
            # Fallback: search by platform_id across all platforms
            fallback_query = platform_id.replace("/", " ").replace("-", " ")
            logger.info("Source track fetch failed, fallback search: %s", fallback_query)
            fingerprints = await self._aggregation.search_tracks_deduped(fallback_query, limit=10)

            if not fingerprints:
                return {
                    "type": "track",
                    "original": {"platform": platform, "platform_id": platform_id, "url": parsed['url']},
                    "matches": [],
                    "error": f"Could not fetch track from {platform} (API key may be missing)",
                }

            # Use best fingerprint as original
            best_fp = fingerprints[0]
            best_source = best_fp.best_source
            if best_source:
                original_meta = best_source

        if original_meta is None:
            return {
                "type": "track",
                "original": {"platform": platform, "platform_id": platform_id, "url": parsed['url']},
                "matches": [],
                "error": f"Could not fetch track from {platform}",
            }

        # 2. Search across all platforms using title + artist
        query = f"{original_meta.title} {original_meta.artist_name}"
        fingerprints = await self._aggregation.search_tracks_deduped(query, limit=20)

        # 3. Find matching fingerprints (same track)
        matches = []
        for fp in fingerprints:
            for source in fp.sources:
                # Skip the original platform source
                if source.platform == platform and source.platform_id == platform_id:
                    continue
                playback = self._playback.resolve(source)
                matches.append({
                    "platform": source.platform,
                    "title": source.title,
                    "artist": source.artist_name,
                    "url": source.url,
                    "thumbnail_url": source.thumbnail_url,
                    "is_playable": source.is_playable,
                    "playback_engine": playback.engine,
                })

        # Deduplicate matches by platform (keep first per platform)
        seen_platforms = set()
        unique_matches = []
        for m in matches:
            if m['platform'] not in seen_platforms:
                seen_platforms.add(m['platform'])
                unique_matches.append(m)

        return {
            "type": "track",
            "original": {
                "platform": platform,
                "title": original_meta.title,
                "artist": original_meta.artist_name,
                "url": parsed['url'],
                "thumbnail_url": original_meta.thumbnail_url,
            },
            "matches": unique_matches,
        }

    async def _crosslink_artist(self, parsed: dict) -> dict:
        """Find the same artist across all platforms."""
        platform = parsed['platform']
        platform_id = parsed['platform_id']

        # 1. Get original artist metadata
        original_artist = await self._aggregation.get_artist(platform, platform_id)

        if original_artist is None:
            # Fallback: try searching by platform_id as query on ALL platforms
            # (e.g., YouTube @handle or channel name)
            fallback_query = platform_id.lstrip("@").replace("/", " ")
            logger.info("Source platform failed, fallback search: %s", fallback_query)
            artists = await self._aggregation.search_artists(fallback_query, limit=10)

            if not artists:
                return {
                    "type": "artist",
                    "original": {"platform": platform, "platform_id": platform_id, "url": parsed['url']},
                    "matches": [],
                    "error": f"Could not fetch artist from {platform} (API key may be missing)",
                }

            # Use the best search result as the "original"
            best = artists[0]
            original_artist = best

        # 2. Search across all platforms using name + aliases
        search_query = original_artist.name
        artists = await self._aggregation.search_artists(search_query, limit=20)

        # 3. Collect matches from different platforms
        matches = []
        for artist in artists:
            platforms_map = artist.extra.get("platforms", {}) if artist.extra else {}
            if platforms_map:
                for p, pid in platforms_map.items():
                    if p == platform and pid == platform_id:
                        continue
                    matches.append({
                        "platform": p,
                        "name": artist.name,
                        "platform_id": pid,
                        "url": artist.url,
                        "image_url": artist.image_url,
                    })
            elif artist.platform != platform or artist.platform_id != platform_id:
                matches.append({
                    "platform": artist.platform,
                    "name": artist.name,
                    "platform_id": artist.platform_id,
                    "url": artist.url,
                    "image_url": artist.image_url,
                })

        # Deduplicate by platform
        seen_platforms = set()
        unique_matches = []
        for m in matches:
            if m['platform'] not in seen_platforms:
                seen_platforms.add(m['platform'])
                unique_matches.append(m)

        return {
            "type": "artist",
            "original": {
                "platform": platform,
                "name": original_artist.name,
                "url": parsed['url'],
                "image_url": original_artist.image_url,
                "aliases": original_artist.aliases,
            },
            "matches": unique_matches,
        }

    def _get_adapter(self, platform: str):
        """Get a specific platform adapter."""
        for adapter in self._aggregation._adapters:
            if adapter.platform_name == platform:
                return adapter
        return None
