"""SoundCloud source adapter."""

import json
import logging
import re

import httpx
from bs4 import BeautifulSoup

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

logger = logging.getLogger(__name__)

SC_API_V2 = "https://api-v2.soundcloud.com"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class SoundCloudAdapter(SourceAdapter):
    """SoundCloud adapter using public API endpoints."""

    def __init__(self):
        self._client = httpx.AsyncClient(timeout=15.0)
        self._client_id: str | None = None

    @property
    def platform_name(self) -> str:
        return "soundcloud"

    @property
    def display_name(self) -> str:
        return "SoundCloud"

    async def _get_client_id(self) -> str | None:
        """Extract client_id from SoundCloud's public pages."""
        if self._client_id:
            return self._client_id

        cached = await cache_get("sc:client_id")
        if cached:
            self._client_id = cached
            return cached

        try:
            resp = await self._client.get(
                "https://soundcloud.com/",
                headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"},
            )
            resp.raise_for_status()

            # Primary: extract from __sc_hydration JSON (apiClient entry)
            hydration_match = re.search(
                r'__sc_hydration\s*=\s*(\[.*?\])\s*;', resp.text, re.DOTALL
            )
            if hydration_match:
                try:
                    hydration = json.loads(hydration_match.group(1))
                    for entry in hydration:
                        if entry.get("hydratable") == "apiClient":
                            client_id = entry.get("data", {}).get("id")
                            if client_id:
                                self._client_id = client_id
                                await cache_set("sc:client_id", self._client_id, 86400)
                                logger.info("SoundCloud client_id obtained via hydration")
                                return self._client_id
                except (json.JSONDecodeError, TypeError):
                    logger.warning("Failed to parse SoundCloud hydration JSON")

            # Fallback: scan JS bundles from sndcdn.com
            soup = BeautifulSoup(resp.text, "html.parser")
            scripts = soup.find_all("script", src=True)
            for script in scripts:
                src = script.get("src", "")
                if "sndcdn.com" in src:
                    js_resp = await self._client.get(src)
                    match = re.search(r'client_id\s*[:=]\s*"([a-zA-Z0-9]+)"', js_resp.text)
                    if match:
                        self._client_id = match.group(1)
                        await cache_set("sc:client_id", self._client_id, 86400)
                        logger.info("SoundCloud client_id obtained via JS fallback")
                        return self._client_id

            logger.warning("SoundCloud client_id extraction failed")
        except httpx.HTTPError as e:
            logger.error("SoundCloud HTTP error during client_id extraction: %s", e)
        return None

    async def _api_get(self, path: str, params: dict | None = None) -> dict | list | None:
        client_id = await self._get_client_id()
        if not client_id:
            return None
        params = params or {}
        params["client_id"] = client_id
        try:
            resp = await self._client.get(f"{SC_API_V2}/{path}", params=params)
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"sc:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_get("search/users", {"q": query, "limit": limit})
        if not data:
            return []

        items = data.get("collection", []) if isinstance(data, dict) else data
        artists = []
        for item in items:
            artists.append(SourceArtist(
                platform="soundcloud",
                platform_id=str(item.get("id", "")),
                name=item.get("username", ""),
                url=item.get("permalink_url", ""),
                image_url=item.get("avatar_url", "").replace("-large", "-t500x500") if item.get("avatar_url") else None,
                description=item.get("description", ""),
                follower_count=item.get("followers_count"),
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"sc:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("search/tracks", {"q": query, "limit": limit})
        if not data:
            return []

        items = data.get("collection", []) if isinstance(data, dict) else data
        tracks = []
        for item in items:
            user = item.get("user", {})
            tracks.append(SourceTrack(
                platform="soundcloud",
                platform_id=str(item.get("id", "")),
                title=item.get("title", ""),
                artist_name=user.get("username", ""),
                url=item.get("permalink_url", ""),
                duration_seconds=item.get("duration", 0) // 1000 if item.get("duration") else None,
                thumbnail_url=item.get("artwork_url", "").replace("-large", "-t500x500") if item.get("artwork_url") else None,
                view_count=item.get("playback_count"),
                like_count=item.get("likes_count"),
                release_date=item.get("created_at", "")[:10] if item.get("created_at") else None,
                is_playable=item.get("streamable", False),
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"sc:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        data = await self._api_get(f"users/{platform_id}")
        if not data or not isinstance(data, dict):
            return None

        artist = SourceArtist(
            platform="soundcloud",
            platform_id=platform_id,
            name=data.get("username", ""),
            url=data.get("permalink_url", ""),
            image_url=data.get("avatar_url", "").replace("-large", "-t500x500") if data.get("avatar_url") else None,
            description=data.get("description", ""),
            follower_count=data.get("followers_count"),
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"sc:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get(f"users/{platform_id}/tracks", {"limit": limit})
        if not data:
            return []

        items = data.get("collection", []) if isinstance(data, dict) else data
        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        tracks = []
        for item in items:
            tracks.append(SourceTrack(
                platform="soundcloud",
                platform_id=str(item.get("id", "")),
                title=item.get("title", ""),
                artist_name=artist_name,
                url=item.get("permalink_url", ""),
                duration_seconds=item.get("duration", 0) // 1000 if item.get("duration") else None,
                thumbnail_url=item.get("artwork_url", "").replace("-large", "-t500x500") if item.get("artwork_url") else None,
                view_count=item.get("playback_count"),
                like_count=item.get("likes_count"),
                is_playable=item.get("streamable", False),
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_stream_url(self, track_id: str) -> str | None:
        """Resolve a direct audio stream URL for a SoundCloud track.

        Uses API v2: GET /tracks/{id} → media.transcodings[] →
        pick progressive format → fetch its url → return actual stream URL.
        """
        cache_key = f"sc:stream:{track_id}"
        cached = await cache_get(cache_key)
        if cached:
            return cached

        data = await self._api_get(f"tracks/{track_id}")
        if not data or not isinstance(data, dict):
            logger.warning("SoundCloud: failed to fetch track %s", track_id)
            return None

        transcodings = data.get("media", {}).get("transcodings", [])
        if not transcodings:
            logger.warning("SoundCloud: no transcodings for track %s", track_id)
            return None

        # Prefer progressive (direct URL) over HLS
        progressive = None
        for tc in transcodings:
            fmt = tc.get("format", {})
            if fmt.get("protocol") == "progressive":
                progressive = tc
                break
        # Fallback to first transcoding if no progressive
        chosen = progressive or transcodings[0]

        transcoding_url = chosen.get("url")
        if not transcoding_url:
            return None

        # Fetch the actual stream URL from the transcoding endpoint
        client_id = await self._get_client_id()
        if not client_id:
            return None

        try:
            resp = await self._client.get(
                transcoding_url, params={"client_id": client_id}
            )
            resp.raise_for_status()
            stream_url = resp.json().get("url")
            if stream_url:
                # Cache for 10 minutes (stream URLs expire)
                await cache_set(cache_key, stream_url, 600)
            return stream_url
        except httpx.HTTPError as e:
            logger.error("SoundCloud: stream URL fetch failed: %s", e)
            return None

    async def is_available(self) -> bool:
        client_id = await self._get_client_id()
        return client_id is not None
