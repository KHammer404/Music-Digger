"""NicoNico source adapter — essential for doujin/vocaloid music."""

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

NICO_NVAPI = "https://nvapi.nicovideo.jp/v2/search/video"
NICO_USER_API = "https://nvapi.nicovideo.jp/v1/users"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class NicoNicoAdapter(SourceAdapter):
    def __init__(self):
        self._client = httpx.AsyncClient(
            timeout=15.0,
            headers={
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
                "X-Frontend-Id": "6",
                "X-Frontend-Version": "0",
            },
        )

    @property
    def platform_name(self) -> str:
        return "niconico"

    @property
    def display_name(self) -> str:
        return "NicoNico"

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
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
            user_name = track.extra.get("user_name", "")
            user_icon = track.extra.get("user_icon")
            artists.append(SourceArtist(
                platform="niconico",
                platform_id=str(user_id),
                name=user_name or f"User {user_id}",
                url=f"https://www.nicovideo.jp/user/{user_id}",
                image_url=user_icon,
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
            resp = await self._client.get(NICO_NVAPI, params={
                "keyword": query,
                "sortKey": "viewCount",
                "sortOrder": "desc",
                "pageSize": min(limit, 100),
            })
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPError:
            return []

        tracks = []
        for item in data.get("data", {}).get("items", []):
            content_id = item.get("id", "")
            owner = item.get("owner", {})
            user_id = owner.get("id", "")
            user_name = owner.get("name", "")
            user_icon = owner.get("iconUrl")
            count = item.get("count", {})
            thumbnail = item.get("thumbnail", {})
            thumb_url = (
                thumbnail.get("middleUrl")
                or thumbnail.get("listingUrl")
                or thumbnail.get("url")
            )
            tracks.append(SourceTrack(
                platform="niconico",
                platform_id=content_id,
                title=item.get("title", ""),
                artist_name=user_name or str(user_id),
                url=f"https://www.nicovideo.jp/watch/{content_id}",
                duration_seconds=item.get("duration"),
                thumbnail_url=thumb_url,
                view_count=count.get("view"),
                like_count=count.get("like"),
                release_date=item.get("registeredAt", "")[:10] if item.get("registeredAt") else None,
                is_playable=True,
                extra={
                    "user_id": str(user_id),
                    "user_name": user_name,
                    "user_icon": user_icon,
                },
            ))

        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"nico:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        # Fetch user info from nvapi
        try:
            resp = await self._client.get(f"{NICO_USER_API}/{platform_id}")
            resp.raise_for_status()
            data = resp.json().get("data", {}).get("user", {})
            name = data.get("nickname", f"User {platform_id}")
            icons = data.get("icons", {})
            image_url = icons.get("large") or icons.get("small")
            description = data.get("description", "")
            # Strip HTML tags from description
            import re
            description = re.sub(r'<[^>]+>', '', description)
        except Exception:
            name = f"NicoNico User {platform_id}"
            image_url = None
            description = None

        artist = SourceArtist(
            platform="niconico",
            platform_id=platform_id,
            name=name,
            url=f"https://www.nicovideo.jp/user/{platform_id}",
            image_url=image_url,
            description=description,
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"nico:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        # Search by artist name and filter by user_id
        tracks = await self._search_videos(artist_name, limit=limit * 2)
        user_tracks = [t for t in tracks if t.extra.get("user_id") == platform_id]

        await cache_set(cache_key, [t.__dict__ for t in user_tracks], SEARCH_CACHE_TTL)
        return user_tracks

    async def is_available(self) -> bool:
        return True
