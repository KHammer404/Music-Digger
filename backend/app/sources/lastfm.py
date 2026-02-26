"""Last.fm source adapter — similar artists and scrobble data."""

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.config import get_settings
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

settings = get_settings()

LASTFM_API = "https://ws.audioscrobbler.com/2.0/"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class LastfmAdapter(SourceAdapter):
    def __init__(self):
        self._api_key = settings.lastfm_api_key
        self._client = httpx.AsyncClient(timeout=15.0)

    @property
    def platform_name(self) -> str:
        return "lastfm"

    @property
    def display_name(self) -> str:
        return "Last.fm"

    async def _api_get(self, method: str, params: dict | None = None) -> dict | None:
        if not self._api_key:
            return None
        base_params = {
            "method": method,
            "api_key": self._api_key,
            "format": "json",
        }
        base_params.update(params or {})
        try:
            resp = await self._client.get(LASTFM_API, params=base_params)
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"lfm:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_get("artist.search", {"artist": query, "limit": limit})
        if not data:
            return []

        results = data.get("results", {}).get("artistmatches", {}).get("artist", [])
        if isinstance(results, dict):
            results = [results]

        artists = []
        for item in results:
            images = item.get("image", [])
            image_url = next((i.get("#text") for i in reversed(images) if i.get("#text")), None)
            artists.append(SourceArtist(
                platform="lastfm",
                platform_id=item.get("mbid") or normalize_name(item.get("name", "")),
                name=item.get("name", ""),
                url=item.get("url", ""),
                image_url=image_url,
                extra={"listeners": int(item.get("listeners", 0))},
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"lfm:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("track.search", {"track": query, "limit": limit})
        if not data:
            return []

        results = data.get("results", {}).get("trackmatches", {}).get("track", [])
        if isinstance(results, dict):
            results = [results]

        tracks = []
        for item in results:
            images = item.get("image", [])
            image_url = next((i.get("#text") for i in reversed(images) if i.get("#text")), None)
            tracks.append(SourceTrack(
                platform="lastfm",
                platform_id=item.get("mbid") or f"{normalize_name(item.get('artist', ''))}:{normalize_name(item.get('name', ''))}",
                title=item.get("name", ""),
                artist_name=item.get("artist", ""),
                url=item.get("url", ""),
                thumbnail_url=image_url,
                is_playable=False,  # Last.fm is metadata-only
                extra={"listeners": int(item.get("listeners", 0))},
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"lfm:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        # Try by MBID first, then by name
        params = {"mbid": platform_id} if len(platform_id) == 36 and "-" in platform_id else {"artist": platform_id}
        data = await self._api_get("artist.getinfo", params)
        if not data or "artist" not in data:
            return None

        info = data["artist"]
        images = info.get("image", [])
        image_url = next((i.get("#text") for i in reversed(images) if i.get("#text")), None)

        artist = SourceArtist(
            platform="lastfm",
            platform_id=platform_id,
            name=info.get("name", ""),
            url=info.get("url", ""),
            image_url=image_url,
            description=info.get("bio", {}).get("summary", ""),
            follower_count=int(info.get("stats", {}).get("listeners", 0)),
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"lfm:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        params = {"mbid": platform_id} if len(platform_id) == 36 and "-" in platform_id else {"artist": platform_id}
        params["limit"] = limit
        data = await self._api_get("artist.gettoptracks", params)
        if not data:
            return []

        results = data.get("toptracks", {}).get("track", [])
        if isinstance(results, dict):
            results = [results]

        tracks = []
        for item in results:
            duration = int(item.get("duration", 0))
            tracks.append(SourceTrack(
                platform="lastfm",
                platform_id=item.get("mbid") or normalize_name(item.get("name", "")),
                title=item.get("name", ""),
                artist_name=item.get("artist", {}).get("name", ""),
                url=item.get("url", ""),
                duration_seconds=duration if duration > 0 else None,
                is_playable=False,
                extra={"listeners": int(item.get("listeners", 0)), "playcount": int(item.get("playcount", 0))},
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_similar_artists(self, platform_id: str, limit: int = 20) -> list[SourceArtist]:
        """Get similar artists — Last.fm's key strength."""
        cache_key = f"lfm:similar:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        params = {"mbid": platform_id} if len(platform_id) == 36 and "-" in platform_id else {"artist": platform_id}
        params["limit"] = limit
        data = await self._api_get("artist.getsimilar", params)
        if not data:
            return []

        results = data.get("similarartists", {}).get("artist", [])
        if isinstance(results, dict):
            results = [results]

        artists = []
        for item in results:
            images = item.get("image", [])
            image_url = next((i.get("#text") for i in reversed(images) if i.get("#text")), None)
            artists.append(SourceArtist(
                platform="lastfm",
                platform_id=item.get("mbid") or normalize_name(item.get("name", "")),
                name=item.get("name", ""),
                url=item.get("url", ""),
                image_url=image_url,
                extra={"match": float(item.get("match", 0))},
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def is_available(self) -> bool:
        return bool(self._api_key)
