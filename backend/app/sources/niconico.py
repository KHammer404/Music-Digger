"""NicoNico source adapter — essential for doujin/vocaloid music."""

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

NICO_SEARCH_API = "https://api.search.nicovideo.jp/api/v2/snapshot/video/contents/search"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class NicoNicoAdapter(SourceAdapter):
    def __init__(self):
        self._client = httpx.AsyncClient(
            timeout=15.0,
            headers={"User-Agent": "MusicDigger/0.1.0"},
        )

    @property
    def platform_name(self) -> str:
        return "niconico"

    @property
    def display_name(self) -> str:
        return "NicoNico"

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        # NicoNico doesn't have a direct artist search API
        # We extract unique uploaders from video search results
        cache_key = f"nico:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        tracks = await self._search_videos(query, limit=limit * 3)

        seen = set()
        artists = []
        for track in tracks:
            user_id = track.extra.get("user_id", "")
            if not user_id or user_id in seen:
                continue
            seen.add(user_id)
            artists.append(SourceArtist(
                platform="niconico",
                platform_id=str(user_id),
                name=track.artist_name,
                url=f"https://www.nicovideo.jp/user/{user_id}",
            ))
            if len(artists) >= limit:
                break

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"nico:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        tracks = await self._search_videos(query, limit=limit)
        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def _search_videos(self, query: str, limit: int = 20) -> list[SourceTrack]:
        try:
            resp = await self._client.get(NICO_SEARCH_API, params={
                "q": query,
                "targets": "title,tags",
                "fields": "contentId,title,userId,channelId,viewCounter,mylistCounter,lengthSeconds,startTime,thumbnailUrl",
                "_sort": "-viewCounter",
                "_limit": min(limit, 100),
                "_context": "MusicDigger",
            })
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPError:
            return []

        tracks = []
        for item in data.get("data", []):
            content_id = item.get("contentId", "")
            user_id = item.get("userId") or item.get("channelId") or ""
            tracks.append(SourceTrack(
                platform="niconico",
                platform_id=content_id,
                title=item.get("title", ""),
                artist_name=str(user_id),  # NicoNico doesn't return username in search
                url=f"https://www.nicovideo.jp/watch/{content_id}",
                duration_seconds=item.get("lengthSeconds"),
                thumbnail_url=item.get("thumbnailUrl"),
                view_count=item.get("viewCounter"),
                like_count=item.get("mylistCounter"),
                release_date=item.get("startTime", "")[:10] if item.get("startTime") else None,
                is_playable=True,
                extra={"user_id": str(user_id)},
            ))

        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"nico:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        # NicoNico user info is limited without auth
        artist = SourceArtist(
            platform="niconico",
            platform_id=platform_id,
            name=f"NicoNico User {platform_id}",
            url=f"https://www.nicovideo.jp/user/{platform_id}",
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"nico:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        # Search by userId
        try:
            resp = await self._client.get(NICO_SEARCH_API, params={
                "q": "",
                "targets": "title",
                "filters[userId][0]": platform_id,
                "fields": "contentId,title,viewCounter,mylistCounter,lengthSeconds,startTime,thumbnailUrl",
                "_sort": "-viewCounter",
                "_limit": min(limit, 100),
                "_context": "MusicDigger",
            })
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPError:
            return []

        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        tracks = []
        for item in data.get("data", []):
            content_id = item.get("contentId", "")
            tracks.append(SourceTrack(
                platform="niconico",
                platform_id=content_id,
                title=item.get("title", ""),
                artist_name=artist_name,
                url=f"https://www.nicovideo.jp/watch/{content_id}",
                duration_seconds=item.get("lengthSeconds"),
                thumbnail_url=item.get("thumbnailUrl"),
                view_count=item.get("viewCounter"),
                like_count=item.get("mylistCounter"),
                release_date=item.get("startTime", "")[:10] if item.get("startTime") else None,
                is_playable=True,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def is_available(self) -> bool:
        return True
